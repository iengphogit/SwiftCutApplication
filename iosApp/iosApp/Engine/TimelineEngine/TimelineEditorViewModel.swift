import SwiftUI
import Combine
import PhotosUI
import UIKit

@MainActor
class TimelineEditorViewModel: ObservableObject {
    @Published var projectName: String = "Project 001"
    @Published var currentTime: CMTime = .zero
    @Published var isPlaying: Bool = false
    @Published var duration: CMTime = .zero
    @Published private(set) var previewSeekCommand: PreviewSeekCommand?
    @Published private(set) var isProjectLoading: Bool = false
    @Published private(set) var compositionFrame: CompositionFrame?
    @Published var tracks: [TrackDisplayModel] = []
    @Published var canUndo: Bool = false
    @Published var canRedo: Bool = false
    @Published private(set) var nativeTimelineSnapshot = NativeTimelineSnapshot(
        canvasWidth: 1080,
        canvasHeight: 1920,
        frameRate: 30,
        trackCount: 0,
        clipCount: 0,
        durationSeconds: 0,
        tracks: []
    )
    
    private var engine = TimelineEngine()
    private let nativeEditorEngine = NativeEditorEngine()
    private let compositionEngine = CompositionEngine()
    private var cancellables = Set<AnyCancellable>()
    private var loadedProjectId: UUID?

    enum ImportDestination {
        case video
        case audio
        case overlay
    }
    
    var currentTimeString: String {
        formatTime(currentTime)
    }
    
    var durationString: String {
        formatTime(duration)
    }
    
    var canSplit: Bool {
        duration.seconds > 0
    }

    init() {
        engine.timelinePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshDisplay()
            }
            .store(in: &cancellables)
        
        nativeEditorEngine.timePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] time in
                self?.currentTime = time
                self?.refreshCompositionFrame(at: time)
            }
            .store(in: &cancellables)
        
        refreshDisplay()
    }
    
    func importMedia(
        url: URL,
        kind: PickedMediaKind,
        destination: ImportDestination,
        at time: CMTime? = nil,
        completion: (() -> Void)? = nil
    ) {
        let trackType: TrackType
        switch destination {
        case .video:
            trackType = .video
        case .audio:
            trackType = .audio
        case .overlay:
            trackType = .overlay
        }

        switch kind {
        case .video:
            importVideoIntoNativeEngine(
                from: url,
                toTrackType: trackType,
                at: time ?? duration,
                completion: completion
            )
        }
    }

    func loadProjectIfNeeded(_ project: WorkspaceProject) {
        guard loadedProjectId != project.id else {
            return
        }

        loadedProjectId = project.id
        isProjectLoading = true
        projectName = project.name
        nativeEditorEngine.stop()
        engine.setTimeline(
            Timeline(
                name: project.name,
                tracks: [
                    Track(type: .video, layer: .videoMain, name: "Video")
                ]
            )
        )
        currentTime = .zero
        duration = .zero
        tracks = []

        let kind: PickedMediaKind
        let destination: ImportDestination

        switch project.mediaKind {
        case .video, .image:
            kind = .video
            destination = .video
        case .audio:
            kind = .video
            destination = .audio
        }

        importMedia(
            url: project.mediaUrl,
            kind: kind,
            destination: destination,
            at: .zero
        ) { [weak self] in
            self?.isProjectLoading = false
        }
    }
    
    func splitAtPlayhead() {
        let affectedClipIds = engine.clips(at: currentTime).map(\.id)
        var didNativeSplit = false

        for clipId in affectedClipIds {
            if nativeEditorEngine.splitClip(id: clipId, at: currentTime.seconds) != nil {
                didNativeSplit = true
            }
        }

        if didNativeSplit {
            applyNativeSnapshotToSwiftTimeline()
            refreshDisplay()
            return
        }

        let newIds = engine.splitAllClips(at: currentTime)
        if !newIds.isEmpty {
            refreshDisplay()
        }
    }
    
    func deleteClip(_ clipId: UUID, ripple: Bool = false) {
        let didDeleteNatively = ripple
            ? nativeEditorEngine.rippleDeleteClip(id: clipId)
            : nativeEditorEngine.removeClip(id: clipId)

        if didDeleteNatively {
            applyNativeSnapshotToSwiftTimeline()
            refreshDisplay()
            return
        }

        engine.removeClip(clipId, ripple: ripple)
        refreshDisplay()
    }

    func undo() {
        if nativeEditorEngine.undo() {
            applyNativeSnapshotToSwiftTimeline()
        } else {
            engine.undo()
        }
        refreshDisplay()
    }

    func redo() {
        if nativeEditorEngine.redo() {
            applyNativeSnapshotToSwiftTimeline()
        } else {
            engine.redo()
        }
        refreshDisplay()
    }

    func addTextOverlay() {
        let didAddClip = nativeEditorEngine.addClip(
            TextClip(
                timelineRange: CMTimeRangeMake(
                    start: currentTime,
                    duration: CMTime(seconds: 5, preferredTimescale: 600)
                ),
                text: "Text Overlay"
            ),
            toTrackType: .text,
            named: "Text"
        )

        if didAddClip {
            applyNativeSnapshotToSwiftTimeline()
            refreshDisplay()
            return
        }

        engine.addTextOverlay()
        refreshDisplay()
    }

    func addDebugClip() {
        let didAddClip = nativeEditorEngine.addClip(
            TextClip(
                timelineRange: CMTimeRangeMake(
                    start: currentTime,
                    duration: CMTime(seconds: 3, preferredTimescale: 600)
                ),
                text: "DEBUG CLIP"
            ),
            toTrackType: .text,
            named: "Text"
        )

        if didAddClip {
            applyNativeSnapshotToSwiftTimeline()
            refreshDisplay()
            return
        }

        engine.addDebugClip()
        refreshDisplay()
    }

    func removeTrack(_ trackId: UUID) {
        if nativeEditorEngine.removeTrack(id: trackId) {
            applyNativeSnapshotToSwiftTimeline()
            refreshDisplay()
            return
        }

        engine.removeTrack(trackId)
        refreshDisplay()
    }

    func setTrackMuted(_ trackId: UUID, muted: Bool) {
        if nativeEditorEngine.setTrackMuted(id: trackId, muted: muted) {
            applyNativeSnapshotToSwiftTimeline()
            refreshDisplay()
            return
        }

        engine.muteTrack(trackId, muted: muted)
        refreshDisplay()
    }

    func setTrackLocked(_ trackId: UUID, locked: Bool) {
        if nativeEditorEngine.setTrackLocked(id: trackId, locked: locked) {
            applyNativeSnapshotToSwiftTimeline()
            refreshDisplay()
            return
        }

        engine.lockTrack(trackId, locked: locked)
        refreshDisplay()
    }
    
    func togglePlayback() {
        if isPlaying {
            nativeEditorEngine.pause()
            isPlaying = false
        } else {
            nativeEditorEngine.play()
            isPlaying = true
        }
    }
    
    func seek(to time: CMTime) {
        nativeEditorEngine.seek(to: time)
        previewSeekCommand = PreviewSeekCommand(timeSeconds: max(time.seconds, 0))
    }

    func syncPreviewDisplayTime(_ seconds: Double) {
        let time = CMTime(seconds: max(seconds, 0), preferredTimescale: 600)
        nativeEditorEngine.seek(to: time)
    }

    func syncPreviewPlaybackState(_ playing: Bool) {
        if isPlaying != playing {
            isPlaying = playing
        }
    }
    
    func exportVideo() {
        do {
            let composition = try engine.buildComposition()
            
            let exportSession = AVAssetExportSession(
                asset: composition,
                presetName: AVAssetExportPresetHighestQuality
            )
            
            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("export_\(UUID().uuidString).mp4")
            
            exportSession?.outputURL = outputURL
            exportSession?.outputFileType = .mp4
            
            exportSession?.exportAsynchronously {
                DispatchQueue.main.async {
                    if exportSession?.status == .completed {
                        self.saveToPhotoLibrary(url: outputURL)
                    }
                }
            }
        } catch {
            print("Export error: \(error)")
        }
    }
    
    private func saveToPhotoLibrary(url: URL) {
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        } completionHandler: { success, error in
            if success {
                print("Saved to photo library")
            } else if let error = error {
                print("Save error: \(error)")
            }
        }
    }
    
    private func refreshDisplay() {
        nativeEditorEngine.configurePlayback(
            frameRate: engine.timeline.settings.frameRate,
            duration: engine.duration
        )

        nativeEditorEngine.synchronizeTimelineIncrementally(
            from: engine.timeline,
            previousSnapshot: nativeTimelineSnapshot
        )
        nativeTimelineSnapshot = nativeEditorEngine.timelineSnapshot()
        duration = CMTime(seconds: nativeTimelineSnapshot.durationSeconds, preferredTimescale: 600)
        tracks = displayTracks(from: nativeTimelineSnapshot)
        canUndo = nativeEditorEngine.canUndo
        canRedo = nativeEditorEngine.canRedo

        refreshCompositionFrame(at: currentTime)
    }
    
}

struct TrackDisplayModel: Identifiable {
    let id: UUID
    let type: TrackType
    let name: String
    let clips: [ClipDisplayModel]
    let isMuted: Bool
    let isLocked: Bool
}

struct ClipDisplayModel: Identifiable {
    let id: UUID
    let type: TrackType
    let name: String
    let startSeconds: Double
    let durationSeconds: Double
    let sourcePath: String
    let hasThumbnail: Bool
}

private extension TimelineEditorViewModel {
    func clipName(_ clip: any ClipProtocol) -> String {
        switch clip {
        case is VideoClip:
            return "Video"
        case is AudioClip:
            return "Audio"
        case is TextClip:
            return (clip as? TextClip)?.text ?? "Text"
        case is OverlayClip:
            return "Overlay"
        default:
            return "Clip"
        }
    }
    
    private func formatTime(_ time: CMTime) -> String {
        let totalSeconds = Int(time.seconds)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let centiseconds = Int((time.seconds.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, centiseconds)
    }

    private func refreshCompositionFrame(at time: CMTime) {
        compositionFrame = compositionEngine.evaluate(
            timeline: engine.timeline,
            at: time
        )
    }

    private func applyNativeSnapshotToSwiftTimeline() {
        let currentTimeline = engine.timeline
        let rebuiltTimeline = Timeline(
            id: currentTimeline.id,
            name: currentTimeline.name,
            createdAt: currentTimeline.createdAt,
            modifiedAt: Date(),
            settings: TimelineSettings(
                canvasSize: CGSize(
                    width: nativeTimelineSnapshot.canvasWidth,
                    height: nativeTimelineSnapshot.canvasHeight
                ),
                frameRate: nativeTimelineSnapshot.frameRate,
                backgroundColor: currentTimeline.settings.backgroundColor
            ),
            tracks: nativeTimelineSnapshot.tracks.compactMap { nativeTrack in
                guard
                    let trackType = TrackType(nativeBridgeName: nativeTrack.type),
                    let layer = TrackLayer(rawValue: nativeTrack.layer)
                else {
                    return nil
                }

                let clips: [any ClipProtocol] = nativeTrack.clips.compactMap { nativeClip in
                    guard let clipType = TrackType(nativeBridgeName: nativeClip.type) else {
                        return nil
                    }

                    let sourceURL = nativeClip.sourcePath.isEmpty ? nil : URL(fileURLWithPath: nativeClip.sourcePath)
                    let timelineRange = CMTimeRange(
                        start: CMTime(seconds: nativeClip.timelineStart, preferredTimescale: 600),
                        duration: CMTime(seconds: nativeClip.timelineDuration, preferredTimescale: 600)
                    )
                    let sourceRange = CMTimeRange(start: .zero, duration: timelineRange.duration)

                    switch clipType {
                    case .video:
                        guard let sourceURL else { return nil }
                        return VideoClip(
                            id: nativeClip.id,
                            sourceUrl: sourceURL,
                            sourceRange: sourceRange,
                            timelineRange: timelineRange
                        )
                    case .audio:
                        guard let sourceURL else { return nil }
                        return AudioClip(
                            id: nativeClip.id,
                            sourceUrl: sourceURL,
                            sourceRange: sourceRange,
                            timelineRange: timelineRange
                        )
                    case .overlay:
                        guard let sourceURL else { return nil }
                        return OverlayClip(
                            id: nativeClip.id,
                            sourceUrl: sourceURL,
                            sourceRange: sourceRange,
                            timelineRange: timelineRange
                        )
                    case .text:
                        return TextClip(
                            id: nativeClip.id,
                            timelineRange: timelineRange,
                            text: nativeClip.name
                        )
                    case .effect:
                        return nil
                    }
                }

                return Track(
                    id: nativeTrack.id,
                    type: trackType,
                    layer: layer,
                    name: nativeTrack.name,
                    isMuted: nativeTrack.muted,
                    isLocked: nativeTrack.locked,
                    clips: clips
                )
            }
        )

        engine.setTimeline(rebuiltTimeline)
    }

    private func displayTracks(from snapshot: NativeTimelineSnapshot) -> [TrackDisplayModel] {
        let nativeTracks = snapshot.tracks.compactMap { nativeTrack -> TrackDisplayModel? in
            guard let trackType = TrackType(nativeBridgeName: nativeTrack.type) else {
                return nil
            }

            return TrackDisplayModel(
                id: nativeTrack.id,
                type: trackType,
                name: nativeTrack.name,
                clips: nativeTrack.clips.compactMap { nativeClip in
                    guard let clipType = TrackType(nativeBridgeName: nativeClip.type) else {
                        return nil
                    }

                    return ClipDisplayModel(
                        id: nativeClip.id,
                        type: clipType,
                        name: nativeClip.name,
                        startSeconds: nativeClip.timelineStart,
                        durationSeconds: nativeClip.timelineDuration,
                        sourcePath: nativeClip.sourcePath,
                        hasThumbnail: clipType == .video || clipType == .overlay
                    )
                },
                isMuted: nativeTrack.muted,
                isLocked: nativeTrack.locked
            )
        }

        if !nativeTracks.isEmpty {
            return nativeTracks.sorted(by: displayTrackOrder)
        }

        let fallbackTracks = engine.timeline.tracks.map { track in
            TrackDisplayModel(
                id: track.id,
                type: track.type,
                name: track.name,
                clips: track.clips.map { clip in
                    ClipDisplayModel(
                        id: clip.id,
                        type: track.type,
                        name: clipName(clip),
                        startSeconds: clip.timelineRange.start.seconds,
                        durationSeconds: clip.timelineRange.duration.seconds,
                        sourcePath: clip.nativeSourcePath ?? "",
                        hasThumbnail: track.type == .video || track.type == .overlay
                    )
                },
                isMuted: track.isMuted,
                isLocked: track.isLocked
            )
        }

        return fallbackTracks.sorted(by: displayTrackOrder)
    }

    private func displayTrackOrder(lhs: TrackDisplayModel, rhs: TrackDisplayModel) -> Bool {
        let lhsPriority = displayPriority(for: lhs.type)
        let rhsPriority = displayPriority(for: rhs.type)

        if lhsPriority == rhsPriority {
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        return lhsPriority < rhsPriority
    }

    private func displayPriority(for type: TrackType) -> Int {
        switch type {
        case .text:
            return 0
        case .overlay:
            return 1
        case .effect:
            return 2
        case .video:
            return 3
        case .audio:
            return 4
        }
    }

    private func importVideoIntoNativeEngine(
        from url: URL,
        toTrackType trackType: TrackType,
        at time: CMTime,
        completion: (() -> Void)? = nil
    ) {
        let asset = AVURLAsset(url: url)

        asset.loadValuesAsynchronously(forKeys: ["duration", "tracks"]) { [weak self] in
            guard let self else { return }

            var error: NSError?
            let durationStatus = asset.statusOfValue(forKey: "duration", error: &error)

            guard durationStatus == .loaded else {
                DispatchQueue.main.async {
                    print("Import error: \(error?.localizedDescription ?? "Failed to load asset duration")")
                    completion?()
                }
                return
            }

            let sourceRange = CMTimeRangeMake(start: .zero, duration: asset.duration)
            let timelineRange = CMTimeRangeMake(start: time, duration: asset.duration)

            let didAddClip: Bool
            switch trackType {
            case .video:
                didAddClip = self.nativeEditorEngine.addClip(
                    VideoClip(
                        sourceUrl: url,
                        sourceRange: sourceRange,
                        timelineRange: timelineRange
                    ),
                    toTrackType: .video,
                    named: "Video"
                )
            case .audio:
                didAddClip = self.nativeEditorEngine.addClip(
                    AudioClip(
                        sourceUrl: url,
                        sourceRange: sourceRange,
                        timelineRange: timelineRange
                    ),
                    toTrackType: .audio,
                    named: "Audio"
                )
            case .overlay:
                didAddClip = self.nativeEditorEngine.addClip(
                    OverlayClip(
                        sourceUrl: url,
                        sourceRange: sourceRange,
                        timelineRange: timelineRange
                    ),
                    toTrackType: .overlay,
                    named: "Overlay"
                )
            case .text, .effect:
                didAddClip = false
            }

            DispatchQueue.main.async {
                guard didAddClip else {
                    print("Import error: Failed to add clip to native timeline")
                    completion?()
                    return
                }

                self.applyNativeSnapshotToSwiftTimeline()
                self.refreshDisplay()
                completion?()
            }
        }
    }
}

private extension TrackType {
    init?(nativeBridgeName: String) {
        switch nativeBridgeName {
        case "video":
            self = .video
        case "audio":
            self = .audio
        case "text":
            self = .text
        case "overlay":
            self = .overlay
        case "effect":
            self = .effect
        default:
            return nil
        }
    }
}
