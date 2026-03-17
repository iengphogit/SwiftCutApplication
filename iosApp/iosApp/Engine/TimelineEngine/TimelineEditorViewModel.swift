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
        extractAudioFromVideo: Bool = true,
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
                extractEmbeddedAudio: extractAudioFromVideo,
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
            extractAudioFromVideo: true,
            at: .zero
        ) { [weak self] in
            self?.isProjectLoading = false
        }
    }
    
    func splitAtPlayhead() {
        let affectedClipIds = Array(Set(
            engine.clips(at: currentTime).flatMap { clip in
                [clip.id] + linkedClipIDs(for: clip.id)
            }
        ))
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
        let linkedClipIds = linkedClipIDs(for: clipId)

        if !linkedClipIds.isEmpty {
            if ripple {
                for linkedClipId in linkedClipIds {
                    _ = nativeEditorEngine.removeClip(id: linkedClipId)
                }
                let didDeletePrimary = nativeEditorEngine.rippleDeleteClip(id: clipId)

                if didDeletePrimary {
                    applyNativeSnapshotToSwiftTimeline()
                    refreshDisplay()
                    return
                }

                for linkedClipId in linkedClipIds {
                    engine.removeClip(linkedClipId, ripple: false)
                }
                engine.removeClip(clipId, ripple: true)
                refreshDisplay()
                return
            }

            var didDeleteNatively = nativeEditorEngine.removeClip(id: clipId)
            for linkedClipId in linkedClipIds {
                didDeleteNatively = nativeEditorEngine.removeClip(id: linkedClipId) && didDeleteNatively
            }

            if didDeleteNatively {
                applyNativeSnapshotToSwiftTimeline()
                refreshDisplay()
                return
            }

            engine.removeClip(clipId, ripple: false)
            for linkedClipId in linkedClipIds {
                engine.removeClip(linkedClipId, ripple: false)
            }
            refreshDisplay()
            return
        }

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

    func moveClip(_ clipId: UUID, to time: CMTime) {
        let linkedClipIds = linkedClipIDs(for: clipId)
        let clampedStartTime = max(.zero, time)

        if !linkedClipIds.isEmpty {
            var didMoveNatively = nativeEditorEngine.moveClip(
                id: clipId,
                timelineStartSeconds: clampedStartTime.seconds
            )
            for linkedClipId in linkedClipIds {
                didMoveNatively = nativeEditorEngine.moveClip(
                    id: linkedClipId,
                    timelineStartSeconds: clampedStartTime.seconds
                ) && didMoveNatively
            }

            if didMoveNatively {
                applyNativeSnapshotToSwiftTimeline()
                refreshDisplay()
                return
            }

            engine.moveClip(clipId, to: clampedStartTime)
            for linkedClipId in linkedClipIds {
                engine.moveClip(linkedClipId, to: clampedStartTime)
            }
            refreshDisplay()
            return
        }

        if nativeEditorEngine.moveClip(id: clipId, timelineStartSeconds: clampedStartTime.seconds) {
            applyNativeSnapshotToSwiftTimeline()
            refreshDisplay()
            return
        }

        engine.moveClip(clipId, to: clampedStartTime)
        refreshDisplay()
    }

    func trimClip(_ clipId: UUID, sourceRange: CMTimeRange) {
        let linkedClipIds = linkedClipIDs(for: clipId)

        if !linkedClipIds.isEmpty {
            var didTrimNatively = nativeEditorEngine.trimClip(
                id: clipId,
                sourceStartSeconds: sourceRange.start.seconds,
                sourceDurationSeconds: sourceRange.duration.seconds
            )
            for linkedClipId in linkedClipIds {
                didTrimNatively = nativeEditorEngine.trimClip(
                    id: linkedClipId,
                    sourceStartSeconds: sourceRange.start.seconds,
                    sourceDurationSeconds: sourceRange.duration.seconds
                ) && didTrimNatively
            }

            if didTrimNatively {
                applyNativeSnapshotToSwiftTimeline()
                refreshDisplay()
                return
            }

            engine.trimClip(clipId, sourceRange: sourceRange)
            for linkedClipId in linkedClipIds {
                engine.trimClip(linkedClipId, sourceRange: sourceRange)
            }
            refreshDisplay()
            return
        }

        if nativeEditorEngine.trimClip(
            id: clipId,
            sourceStartSeconds: sourceRange.start.seconds,
            sourceDurationSeconds: sourceRange.duration.seconds
        ) {
            applyNativeSnapshotToSwiftTimeline()
            refreshDisplay()
            return
        }

        engine.trimClip(clipId, sourceRange: sourceRange)
        refreshDisplay()
    }

    func trimClipLeadingEdge(
        _ clipId: UUID,
        timelineStartSeconds: Double,
        sourceStartSeconds: Double,
        sourceDurationSeconds: Double
    ) {
        let sourceRange = CMTimeRange(
            start: CMTime(seconds: max(0, sourceStartSeconds), preferredTimescale: 600),
            duration: CMTime(seconds: max(0.05, sourceDurationSeconds), preferredTimescale: 600)
        )
        trimClip(clipId, sourceRange: sourceRange)
        moveClip(
            clipId,
            to: CMTime(seconds: max(0, timelineStartSeconds), preferredTimescale: 600)
        )
    }

    func trimClipTrailingEdge(
        _ clipId: UUID,
        sourceStartSeconds: Double,
        sourceDurationSeconds: Double
    ) {
        let sourceRange = CMTimeRange(
            start: CMTime(seconds: max(0, sourceStartSeconds), preferredTimescale: 600),
            duration: CMTime(seconds: max(0.05, sourceDurationSeconds), preferredTimescale: 600)
        )
        trimClip(clipId, sourceRange: sourceRange)
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

    func canExtractAudio(from clipId: UUID) -> Bool {
        guard let (_, clip) = engine.timeline.clip(for: clipId),
              let videoClip = clip as? VideoClip else {
            return false
        }

        return !hasMatchingAudioClip(for: videoClip)
    }

    func extractAudio(from clipId: UUID) {
        guard let (_, clip) = engine.timeline.clip(for: clipId),
              let videoClip = clip as? VideoClip,
              !hasMatchingAudioClip(for: videoClip) else {
            return
        }

        let linkedClipGroupId = videoClip.linkedClipGroupId ?? UUID()

        let didAddAudioClip = nativeEditorEngine.addClip(
            AudioClip(
                linkedClipGroupId: linkedClipGroupId,
                sourceUrl: videoClip.sourceUrl,
                sourceRange: videoClip.sourceRange,
                timelineRange: videoClip.timelineRange
            ),
            toTrackType: .audio,
            named: "Audio"
        )

        guard didAddAudioClip else {
            AppLogger.log("Extract audio error: Failed to add extracted audio clip")
            return
        }

        applyNativeSnapshotToSwiftTimeline()
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
            AppLogger.log("Export error: \(error.localizedDescription)")
        }
    }
    
    private func saveToPhotoLibrary(url: URL) {
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        } completionHandler: { success, error in
            if success {
                AppLogger.log("Saved to photo library")
            } else if let error = error {
                AppLogger.log("Save error: \(error.localizedDescription)")
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
    let sourceStartSeconds: Double
    let sourceDurationSeconds: Double
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
        let existingClipsByID = Dictionary(
            uniqueKeysWithValues: currentTimeline.tracks
                .flatMap(\.clips)
                .map { ($0.id, $0) }
        )
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
                    let existingClip = existingClipsByID[nativeClip.id]
                    let sourceRange = existingClip?.sourceRange ?? CMTimeRange(
                        start: CMTime(seconds: nativeClip.sourceStart, preferredTimescale: 600),
                        duration: CMTime(seconds: nativeClip.sourceDuration, preferredTimescale: 600)
                    )
                    let linkedClipGroupId = {
                        if let videoClip = existingClip as? VideoClip {
                            return videoClip.linkedClipGroupId
                        }
                        if let audioClip = existingClip as? AudioClip {
                            return audioClip.linkedClipGroupId
                        }
                        return nil
                    }()

                    switch clipType {
                    case .video:
                        guard let sourceURL else { return nil }
                        return VideoClip(
                            id: nativeClip.id,
                            linkedClipGroupId: linkedClipGroupId,
                            sourceUrl: sourceURL,
                            sourceRange: sourceRange,
                            timelineRange: timelineRange
                        )
                    case .audio:
                        guard let sourceURL else { return nil }
                        return AudioClip(
                            id: nativeClip.id,
                            linkedClipGroupId: linkedClipGroupId,
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
                        sourceStartSeconds: nativeClip.sourceStart,
                        sourceDurationSeconds: nativeClip.sourceDuration,
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
                        sourceStartSeconds: clip.sourceRange.start.seconds,
                        sourceDurationSeconds: clip.sourceRange.duration.seconds,
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
        extractEmbeddedAudio: Bool,
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
                    AppLogger.log("Import error: \(error?.localizedDescription ?? "Failed to load asset duration")")
                    completion?()
                }
                return
            }

            let sourceRange = CMTimeRangeMake(start: .zero, duration: asset.duration)
            let timelineRange = CMTimeRangeMake(start: time, duration: asset.duration)
            let hasEmbeddedAudio = !asset.tracks(withMediaType: .audio).isEmpty
            let linkedClipGroupId = trackType == .video && extractEmbeddedAudio && hasEmbeddedAudio
                ? UUID()
                : nil

            let didAddClip: Bool
            switch trackType {
            case .video:
                didAddClip = self.nativeEditorEngine.addClip(
                    VideoClip(
                        linkedClipGroupId: linkedClipGroupId,
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
                    AppLogger.log("Import error: Failed to add clip to native timeline")
                    completion?()
                    return
                }

                if trackType == .video && extractEmbeddedAudio && hasEmbeddedAudio {
                    let didAddAudioClip = self.nativeEditorEngine.addClip(
                        AudioClip(
                            linkedClipGroupId: linkedClipGroupId,
                            sourceUrl: url,
                            sourceRange: sourceRange,
                            timelineRange: timelineRange
                        ),
                        toTrackType: .audio,
                        named: "Audio"
                    )

                    if !didAddAudioClip {
                        AppLogger.log("Import warning: Failed to extract embedded audio to audio track")
                    }
                }

                self.applyNativeSnapshotToSwiftTimeline()
                self.refreshDisplay()
                completion?()
            }
        }
    }

    private func hasMatchingAudioClip(for videoClip: VideoClip) -> Bool {
        if let linkedClipGroupId = videoClip.linkedClipGroupId {
            return engine.timeline.tracks
                .filter { $0.type == .audio }
                .flatMap(\.clips)
                .compactMap { $0 as? AudioClip }
                .contains { $0.linkedClipGroupId == linkedClipGroupId }
        }

        return engine.timeline.tracks
            .filter { $0.type == .audio }
            .flatMap(\.clips)
            .contains { clip in
                guard let audioClip = clip as? AudioClip else {
                    return false
                }

                return audioClip.sourceUrl == videoClip.sourceUrl &&
                    abs(audioClip.timelineRange.start.seconds - videoClip.timelineRange.start.seconds) < 0.001 &&
                    abs(audioClip.timelineRange.duration.seconds - videoClip.timelineRange.duration.seconds) < 0.001 &&
                    abs(audioClip.sourceRange.start.seconds - videoClip.sourceRange.start.seconds) < 0.001 &&
                    abs(audioClip.sourceRange.duration.seconds - videoClip.sourceRange.duration.seconds) < 0.001
            }
    }

    private func linkedClipIDs(for clipId: UUID) -> [UUID] {
        guard let (_, clip) = engine.timeline.clip(for: clipId) else {
            return []
        }

        if let videoClip = clip as? VideoClip {
            return matchingAudioClips(for: videoClip).map(\.id)
        }

        if let audioClip = clip as? AudioClip {
            return matchingVideoClips(for: audioClip).map(\.id)
        }

        return []
    }

    private func matchingAudioClips(for videoClip: VideoClip) -> [AudioClip] {
        if let linkedClipGroupId = videoClip.linkedClipGroupId {
            return engine.timeline.tracks
                .filter { $0.type == .audio }
                .flatMap(\.clips)
                .compactMap { $0 as? AudioClip }
                .filter { $0.linkedClipGroupId == linkedClipGroupId }
        }

        return engine.timeline.tracks
            .filter { $0.type == .audio }
            .flatMap(\.clips)
            .compactMap { $0 as? AudioClip }
            .filter { audioClip in
                audioClip.sourceUrl == videoClip.sourceUrl &&
                    abs(audioClip.timelineRange.start.seconds - videoClip.timelineRange.start.seconds) < 0.001 &&
                    abs(audioClip.timelineRange.duration.seconds - videoClip.timelineRange.duration.seconds) < 0.001 &&
                    abs(audioClip.sourceRange.start.seconds - videoClip.sourceRange.start.seconds) < 0.001 &&
                    abs(audioClip.sourceRange.duration.seconds - videoClip.sourceRange.duration.seconds) < 0.001
            }
    }

    private func matchingVideoClips(for audioClip: AudioClip) -> [VideoClip] {
        if let linkedClipGroupId = audioClip.linkedClipGroupId {
            return engine.timeline.tracks
                .filter { $0.type == .video }
                .flatMap(\.clips)
                .compactMap { $0 as? VideoClip }
                .filter { $0.linkedClipGroupId == linkedClipGroupId }
        }

        return engine.timeline.tracks
            .filter { $0.type == .video }
            .flatMap(\.clips)
            .compactMap { $0 as? VideoClip }
            .filter { videoClip in
                videoClip.sourceUrl == audioClip.sourceUrl &&
                    abs(videoClip.timelineRange.start.seconds - audioClip.timelineRange.start.seconds) < 0.001 &&
                    abs(videoClip.timelineRange.duration.seconds - audioClip.timelineRange.duration.seconds) < 0.001 &&
                    abs(videoClip.sourceRange.start.seconds - audioClip.sourceRange.start.seconds) < 0.001 &&
                    abs(videoClip.sourceRange.duration.seconds - audioClip.sourceRange.duration.seconds) < 0.001
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
