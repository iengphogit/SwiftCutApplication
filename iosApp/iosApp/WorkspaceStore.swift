import Foundation
import Combine
import AVFoundation
import UIKit

struct WorkspaceProject: Identifiable, Hashable {
    let id: UUID
    let name: String
    let mediaUrl: URL
    let createdAt: Date
    let mediaKind: MediaKind
    let projectNumber: Int
    let aspectRatio: AspectRatio
    let resolution: UhdResolution
    let frameRate: UhdFrameRate
    let bitrate: UhdBitrate

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
        if ProcessInfo.processInfo.arguments.contains("UITEST_SEED_PROJECTS") {
            let shouldReset = ProcessInfo.processInfo.arguments.contains("UITEST_RESET_WORKSPACE")
            let storageBaseUrl = storageBaseUrl
            await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .utility).async {
                    Self.seedUITestWorkspaceIfNeeded(
                        at: storageBaseUrl,
                        resetExistingWorkspace: shouldReset
                    )
                    continuation.resume()
                }
            }
        }

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
            projectNumber: nextNumber,
            aspectRatio: .ratio16x9,
            resolution: .p1080,
            frameRate: .fps24,
            bitrate: .mbps5
        )
        projects.insert(newProject, at: 0)
        saveWorkspace(projects)
        return newProject
    }

    func updateAspectRatio(for projectId: UUID, aspectRatio: AspectRatio) {
        guard let index = projects.firstIndex(where: { $0.id == projectId }) else {
            return
        }
        let project = projects[index]
        let updatedProject = WorkspaceProject(
            id: project.id,
            name: project.name,
            mediaUrl: project.mediaUrl,
            createdAt: project.createdAt,
            mediaKind: project.mediaKind,
            projectNumber: project.projectNumber,
            aspectRatio: aspectRatio,
            resolution: project.resolution,
            frameRate: project.frameRate,
            bitrate: project.bitrate
        )
        projects[index] = updatedProject
        saveWorkspace(projects)
    }

    func updateUhdSettings(
        for projectId: UUID,
        resolution: UhdResolution,
        frameRate: UhdFrameRate,
        bitrate: UhdBitrate
    ) {
        guard let index = projects.firstIndex(where: { $0.id == projectId }) else {
            return
        }
        let project = projects[index]
        let updatedProject = WorkspaceProject(
            id: project.id,
            name: project.name,
            mediaUrl: project.mediaUrl,
            createdAt: project.createdAt,
            mediaKind: project.mediaKind,
            projectNumber: project.projectNumber,
            aspectRatio: project.aspectRatio,
            resolution: resolution,
            frameRate: frameRate,
            bitrate: bitrate
        )
        projects[index] = updatedProject
        saveWorkspace(projects)
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
                projectNumber: project.projectNumber,
                aspectRatio: project.aspectRatio,
                resolution: project.resolution,
                frameRate: project.frameRate,
                bitrate: project.bitrate
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
                projectNumber: projectNumber,
                aspectRatio: project.aspectRatio ?? .ratio16x9,
                resolution: project.resolution ?? .p1080,
                frameRate: project.frameRate ?? .fps24,
                bitrate: project.bitrate ?? .mbps5
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
                projectNumber: $0.projectNumber,
                aspectRatio: $0.aspectRatio,
                resolution: $0.resolution,
                frameRate: $0.frameRate,
                bitrate: $0.bitrate
            )
        }
        let record = WorkspaceRecord(projects: records)
        guard let data = try? JSONEncoder().encode(record) else {
            return
        }
        try? fileManager.createDirectory(at: storageBaseUrl, withIntermediateDirectories: true)
        try? data.write(to: workspaceFileUrl, options: .atomic)
    }

    private static func seedUITestWorkspaceIfNeeded(
        at storageBaseUrl: URL,
        resetExistingWorkspace: Bool
    ) {
        let fileManager = FileManager.default
        let projectsDirectoryUrl = storageBaseUrl.appendingPathComponent("Projects")
        let workspaceFileUrl = storageBaseUrl.appendingPathComponent("workspace.json")

        if resetExistingWorkspace {
            try? fileManager.removeItem(at: storageBaseUrl)
        } else if fileManager.fileExists(atPath: workspaceFileUrl.path) {
            return
        }

        try? fileManager.createDirectory(at: projectsDirectoryUrl, withIntermediateDirectories: true)

        let now = Date()
        let seededProjects: [(Int, String, MediaKind, TimeInterval)] = [
            (1, "Project 001", .video, -180),
            (2, "Project 002", .video, -120),
            (3, "Project 003", .video, -60)
        ]

        var records: [ProjectRecord] = []
        for (number, name, mediaKind, offset) in seededProjects {
            let projectDirectory = projectsDirectoryUrl
                .appendingPathComponent(projectFolderName(for: number), isDirectory: true)
            try? fileManager.createDirectory(at: projectDirectory, withIntermediateDirectories: true)

            let mediaUrl = projectDirectory.appendingPathComponent("media.mov")
            if !fileManager.fileExists(atPath: mediaUrl.path) {
                createUITestVideo(at: mediaUrl, label: name)
            }

            records.append(
                ProjectRecord(
                    id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", number)) ?? UUID(),
                    name: name,
                    mediaPath: mediaUrl.path,
                    createdAt: now.addingTimeInterval(offset),
                    isVideo: mediaKind == .video,
                    mediaKind: mediaKind,
                    projectNumber: number,
                    aspectRatio: .ratio16x9,
                    resolution: .p1080,
                    frameRate: .fps24,
                    bitrate: .mbps5
                )
            )
        }

        let record = WorkspaceRecord(projects: records)
        guard let data = try? JSONEncoder().encode(record) else {
            return
        }
        try? fileManager.createDirectory(at: storageBaseUrl, withIntermediateDirectories: true)
        try? data.write(to: workspaceFileUrl, options: .atomic)
    }

    private static func createUITestVideo(at url: URL, label: String) {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: url)

        let writer: AVAssetWriter
        do {
            writer = try AVAssetWriter(url: url, fileType: .mov)
        } catch {
            return
        }

        let size = CGSize(width: 720, height: 1280)
        let outputSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height)
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
        input.expectsMediaDataInRealTime = false

        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height),
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: attributes
        )

        guard writer.canAdd(input) else { return }
        writer.add(input)
        guard writer.startWriting() else { return }
        writer.startSession(atSourceTime: .zero)

        let frameCount = 24
        let frameDuration = CMTime(value: 1, timescale: 12)
        for frameIndex in 0..<frameCount {
            while !input.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.005)
            }
            guard let pixelBuffer = makeUITestPixelBuffer(
                size: size,
                label: label,
                frameIndex: frameIndex
            ) else {
                continue
            }
            let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(frameIndex))
            adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
        }

        input.markAsFinished()

        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting {
            semaphore.signal()
        }
        semaphore.wait()

        if writer.status != .completed {
            try? fileManager.removeItem(at: url)
        }
    }

    private static func makeUITestPixelBuffer(
        size: CGSize,
        label: String,
        frameIndex: Int
    ) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32BGRA,
            [
                kCVPixelBufferCGImageCompatibilityKey: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey: true
            ] as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else {
            return nil
        }

        let colors: [UIColor] = [
            UIColor(red: 0.16, green: 0.45, blue: 0.95, alpha: 1),
            UIColor(red: 0.15, green: 0.76, blue: 0.51, alpha: 1),
            UIColor(red: 0.96, green: 0.64, blue: 0.19, alpha: 1)
        ]
        let background = colors[frameIndex % colors.count]
        context.setFillColor(background.cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        let stripeHeight = size.height / 5
        for index in 0..<5 {
            let alpha = CGFloat(0.08 * Double(index + frameIndex % 3 + 1))
            context.setFillColor(UIColor.white.withAlphaComponent(alpha).cgColor)
            context.fill(CGRect(x: 0, y: CGFloat(index) * stripeHeight, width: size.width, height: stripeHeight))
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 78, weight: .bold),
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraph
        ]
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 32, weight: .medium),
            .foregroundColor: UIColor.white.withAlphaComponent(0.85)
        ]

        UIGraphicsPushContext(context)
        defer { UIGraphicsPopContext() }

        NSString(string: label).draw(in: CGRect(x: 56, y: 96, width: size.width - 112, height: 120), withAttributes: attributes)
        NSString(string: "Frame \(frameIndex + 1)").draw(
            in: CGRect(x: 56, y: 196, width: size.width - 112, height: 64),
            withAttributes: subtitleAttributes
        )

        return pixelBuffer
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

enum AspectRatio: String, Codable, CaseIterable, Hashable {
    case ratio16x9 = "16:9"
    case ratio9x16 = "9:16"
    case ratio1x1 = "1:1"

    var displayName: String {
        rawValue
    }

    var previewCanvasSize: CGSize {
        switch self {
        case .ratio16x9:
            return CGSize(width: 1920, height: 1080)
        case .ratio9x16:
            return CGSize(width: 1080, height: 1920)
        case .ratio1x1:
            return CGSize(width: 1080, height: 1080)
        }
    }

    func canvasSize(for resolution: UhdResolution) -> CGSize {
        let longEdge = CGFloat(resolution.longEdgePixels)
        switch self {
        case .ratio16x9:
            return CGSize(width: longEdge, height: round(longEdge * 9.0 / 16.0))
        case .ratio9x16:
            return CGSize(width: round(longEdge * 9.0 / 16.0), height: longEdge)
        case .ratio1x1:
            return CGSize(width: longEdge, height: longEdge)
        }
    }
}

enum UhdResolution: String, Codable, CaseIterable, Hashable {
    case p1080 = "1080P"
    case k2 = "2K"
    case k4 = "4K"
    case k8 = "8K"

    var displayName: String {
        rawValue
    }

    var longEdgePixels: Int {
        switch self {
        case .p1080:
            return 1080
        case .k2:
            return 2048
        case .k4:
            return 3840
        case .k8:
            return 7680
        }
    }
}

enum UhdFrameRate: String, Codable, CaseIterable, Hashable {
    case fps24 = "24"
    case fps25 = "25"
    case fps30 = "30"
    case fps50 = "50"
    case fps60 = "60"

    var displayName: String {
        rawValue
    }

    var framesPerSecond: Int {
        Int(rawValue) ?? 30
    }
}

enum UhdBitrate: String, Codable, CaseIterable, Hashable {
    case mbps5 = "5"
    case mbps10 = "10"
    case mbps20 = "20"
    case mbps50 = "50"
    case mbps100 = "100"

    var displayName: String {
        rawValue
    }
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
    let aspectRatio: AspectRatio?
    let resolution: UhdResolution?
    let frameRate: UhdFrameRate?
    let bitrate: UhdBitrate?
}
