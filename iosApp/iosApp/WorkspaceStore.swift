import Foundation
import Combine

struct WorkspaceProject: Identifiable, Hashable {
    let id: UUID
    let name: String
    let mediaUrl: URL
    let createdAt: Date
    let mediaKind: MediaKind
    let projectNumber: Int

    var isVideo: Bool {
        mediaKind == .video
    }

    var isAudio: Bool {
        mediaKind == .audio
    }
}

@MainActor
final class WorkspaceStore: ObservableObject {
    @Published private(set) var projects: [WorkspaceProject] = []

    private let fileManager = FileManager.default
    private let workspaceFileName = "workspace.json"
    private let legacyProjectsFolder = "Projects"

    func load() async {
        let workspaceUrl = workspaceFileUrl
        let loadedProjects = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let projects = Self.loadWorkspace(from: workspaceUrl)
                    .sorted { $0.createdAt > $1.createdAt }
                continuation.resume(returning: projects)
            }
        }
        if loadedProjects.isEmpty {
            migrateLegacyWorkspaceIfNeeded()
            let migratedProjects = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .utility).async {
                    let projects = Self.loadWorkspace(from: self.workspaceFileUrl)
                        .sorted { $0.createdAt > $1.createdAt }
                    continuation.resume(returning: projects)
                }
            }
            projects = migratedProjects
        } else {
            projects = loadedProjects
        }
    }

    func project(withId id: UUID) -> WorkspaceProject? {
        projects.first { $0.id == id }
    }

    func createProject(from payload: MediaPayload) -> WorkspaceProject? {
        let nextNumber = nextProjectNumber()
        let projectCode = String(format: "%03d", nextNumber)
        let projectName = "Project \(projectCode)"
        let projectId = UUID()
        let projectDirectory = projectsDirectoryUrl.appendingPathComponent(Self.projectFolderName(for: nextNumber))
        let mediaFileUrl = projectDirectory.appendingPathComponent("media.\(payload.fileExtension)")

        do {
            try fileManager.createDirectory(
                at: projectsDirectoryUrl,
                withIntermediateDirectories: true,
                attributes: nil
            )
            try fileManager.createDirectory(
                at: projectDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            try payload.data.write(to: mediaFileUrl, options: .atomic)
        } catch {
            return nil
        }

        let newProject = WorkspaceProject(
            id: projectId,
            name: projectName,
            mediaUrl: mediaFileUrl,
            createdAt: Date(),
            mediaKind: payload.mediaKind,
            projectNumber: nextNumber
        )
        projects.insert(newProject, at: 0)
        saveWorkspace(projects)
        return newProject
    }

    func deleteProject(_ project: WorkspaceProject) {
        projects.removeAll { $0.id == project.id }
        saveWorkspace(projects)
        let projectDirectory = projectsDirectoryUrl
            .appendingPathComponent(Self.projectFolderName(for: project.projectNumber))
        try? fileManager.removeItem(at: projectDirectory)
        let legacyDirectory = projectsDirectoryUrl
            .appendingPathComponent(String(format: "%03d", project.projectNumber))
        try? fileManager.removeItem(at: legacyDirectory)
    }

    private var storageBaseUrl: URL {
        Self.storageBaseUrl(fileManager: fileManager)
    }

    private var workspaceFileUrl: URL {
        storageBaseUrl.appendingPathComponent(workspaceFileName)
    }

    private var projectsDirectoryUrl: URL {
        storageBaseUrl.appendingPathComponent("Projects")
    }

    private func nextProjectNumber() -> Int {
        let currentMax = projects.map(
            { $0.projectNumber }
        ).max() ?? 0
        return currentMax + 1
    }

    private static func projectFolderName(for projectNumber: Int) -> String {
        "Project \(String(format: "%03d", projectNumber))"
    }

    private func migrateLegacyWorkspaceIfNeeded() {
        let legacyBaseUrl = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let legacyWorkspaceUrl = legacyBaseUrl.appendingPathComponent(workspaceFileName)
        let legacyProjectsUrl = legacyBaseUrl.appendingPathComponent(legacyProjectsFolder)
        let legacyProjects = Self.loadWorkspace(from: legacyWorkspaceUrl)
        guard !legacyProjects.isEmpty else {
            return
        }

        try? fileManager.createDirectory(at: storageBaseUrl, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: projectsDirectoryUrl, withIntermediateDirectories: true)

        let updatedProjects = legacyProjects.map { project -> WorkspaceProject in
            let projectFolder = String(format: "%03d", project.projectNumber)
            let legacyProjectUrl = legacyProjectsUrl.appendingPathComponent(projectFolder)
            let newProjectUrl = projectsDirectoryUrl
                .appendingPathComponent(Self.projectFolderName(for: project.projectNumber))
            if fileManager.fileExists(atPath: legacyProjectUrl.path),
               !fileManager.fileExists(atPath: newProjectUrl.path) {
                try? fileManager.moveItem(at: legacyProjectUrl, to: newProjectUrl)
            }
            let fileExtension = project.mediaUrl.pathExtension
            let fallbackExtension = project.mediaKind == .video ? "mov" : project.mediaKind == .audio ? "m4a" : "jpg"
            let mediaExtension = fileExtension.isEmpty ? fallbackExtension : fileExtension
            let mediaUrl = newProjectUrl.appendingPathComponent("media.\(mediaExtension)")
            return WorkspaceProject(
                id: project.id,
                name: project.name,
                mediaUrl: mediaUrl,
                createdAt: project.createdAt,
                mediaKind: project.mediaKind,
                projectNumber: project.projectNumber
            )
        }
        saveWorkspace(updatedProjects)
        try? fileManager.removeItem(at: legacyWorkspaceUrl)
    }

    private static func storageBaseUrl(fileManager: FileManager) -> URL {
        let baseUrl = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return baseUrl.appendingPathComponent("SwiftCut", isDirectory: true)
    }

    private static func loadWorkspace(from url: URL) -> [WorkspaceProject] {
        guard
            let data = try? Data(contentsOf: url),
            let record = try? JSONDecoder().decode(WorkspaceRecord.self, from: data)
        else {
            return []
        }
        return record.projects.compactMap { project in
            let mediaKind = project.mediaKind
                ?? (project.isVideo == true ? .video : .image)
            let projectNumber = project.projectNumber
                ?? Int(project.name.components(separatedBy: CharacterSet.decimalDigits.inverted).joined())
                ?? 0
            let storageBaseUrl = Self.storageBaseUrl(fileManager: FileManager.default)
            let projectsDirectoryUrl = storageBaseUrl.appendingPathComponent("Projects")
            let fileExtension = URL(fileURLWithPath: project.mediaPath).pathExtension
            let fallbackExtension = mediaKind == .video ? "mov" : mediaKind == .audio ? "m4a" : "jpg"
            let mediaExtension = fileExtension.isEmpty ? fallbackExtension : fileExtension
            let fallbackUrl = projectsDirectoryUrl
                .appendingPathComponent(Self.projectFolderName(for: projectNumber))
                .appendingPathComponent("media.\(mediaExtension)")
            let existingUrl = URL(fileURLWithPath: project.mediaPath)
            let mediaUrl = FileManager.default.fileExists(atPath: existingUrl.path)
                ? existingUrl
                : fallbackUrl
            return WorkspaceProject(
                id: project.id,
                name: project.name,
                mediaUrl: mediaUrl,
                createdAt: project.createdAt,
                mediaKind: mediaKind,
                projectNumber: projectNumber
            )
        }
    }

    private func saveWorkspace(_ projects: [WorkspaceProject]) {
        let records = projects.map {
            ProjectRecord(
                id: $0.id,
                name: $0.name,
                mediaPath: $0.mediaUrl.path,
                createdAt: $0.createdAt,
                isVideo: $0.isVideo,
                mediaKind: $0.mediaKind,
                projectNumber: $0.projectNumber
            )
        }
        let record = WorkspaceRecord(projects: records)
        guard let data = try? JSONEncoder().encode(record) else {
            return
        }
        try? fileManager.createDirectory(at: storageBaseUrl, withIntermediateDirectories: true)
        try? data.write(to: workspaceFileUrl, options: .atomic)
    }

}

struct MediaPayload {
    let data: Data
    let fileExtension: String
    let mediaKind: MediaKind

    var isVideo: Bool {
        mediaKind == .video
    }

    var isAudio: Bool {
        mediaKind == .audio
    }
}

enum MediaKind: String, Codable {
    case image
    case video
    case audio
}

private struct WorkspaceRecord: Codable {
    let projects: [ProjectRecord]
}

private struct ProjectRecord: Codable {
    let id: UUID
    let name: String
    let mediaPath: String
    let createdAt: Date
    let isVideo: Bool?
    let mediaKind: MediaKind?
    let projectNumber: Int?
}
