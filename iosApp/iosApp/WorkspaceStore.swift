import Foundation
import Combine

struct WorkspaceProject: Identifiable, Hashable {
    let id: UUID
    let name: String
    let mediaUrl: URL
    let createdAt: Date
    let isVideo: Bool
}

@MainActor
final class WorkspaceStore: ObservableObject {
    @Published private(set) var projects: [WorkspaceProject] = []

    private let fileManager = FileManager.default
    private let workspaceFileName = "workspace.json"

    func load() async {
        let workspaceUrl = workspaceFileUrl
        let loadedProjects = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let projects = Self.loadWorkspace(from: workspaceUrl)
                    .sorted { $0.createdAt > $1.createdAt }
                continuation.resume(returning: projects)
            }
        }
        projects = loadedProjects
    }

    func project(withId id: UUID) -> WorkspaceProject? {
        projects.first { $0.id == id }
    }

    func createProject(from payload: MediaPayload) -> WorkspaceProject? {
        let projectName = "Project \(projects.count + 1)"
        let projectId = UUID()
        let projectDirectory = projectsDirectoryUrl.appendingPathComponent(projectId.uuidString)
        let mediaFileUrl = projectDirectory.appendingPathComponent("media.\(payload.fileExtension)")

        do {
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
            isVideo: payload.isVideo
        )
        projects.insert(newProject, at: 0)
        saveWorkspace(projects)
        return newProject
    }

    private var cacheBaseUrl: URL {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
    }

    private var workspaceFileUrl: URL {
        cacheBaseUrl.appendingPathComponent(workspaceFileName)
    }

    private var projectsDirectoryUrl: URL {
        cacheBaseUrl.appendingPathComponent("Projects")
    }

    private static func loadWorkspace(from url: URL) -> [WorkspaceProject] {
        guard
            let data = try? Data(contentsOf: url),
            let record = try? JSONDecoder().decode(WorkspaceRecord.self, from: data)
        else {
            return []
        }
        return record.projects.compactMap { project in
            WorkspaceProject(
                id: project.id,
                name: project.name,
                mediaUrl: URL(fileURLWithPath: project.mediaPath),
                createdAt: project.createdAt,
                isVideo: project.isVideo
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
                isVideo: $0.isVideo
            )
        }
        let record = WorkspaceRecord(projects: records)
        guard let data = try? JSONEncoder().encode(record) else {
            return
        }
        try? data.write(to: workspaceFileUrl, options: .atomic)
    }

}

struct MediaPayload {
    let data: Data
    let fileExtension: String
    let isVideo: Bool
}

private struct WorkspaceRecord: Codable {
    let projects: [ProjectRecord]
}

private struct ProjectRecord: Codable {
    let id: UUID
    let name: String
    let mediaPath: String
    let createdAt: Date
    let isVideo: Bool
}
