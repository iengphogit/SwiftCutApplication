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
    @Published private(set) var compositionFrame: CompositionFrame?
    @Published var tracks: [TrackDisplayModel] = []
    @Published var canUndo: Bool = false
    @Published var canRedo: Bool = false
    @Published private(set) var nativeTimelineSnapshot = NativeTimelineSnapshot(
        trackCount: 0,
        clipCount: 0,
        durationSeconds: 0
    )
    
    private var engine = TimelineEngine()
    private let nativeEditorEngine = NativeEditorEngine()
    private let compositionEngine = CompositionEngine()
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()

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

    var previewPlayer: AVPlayer? {
        player
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
        destination: ImportDestination
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
            engine.importVideo(from: url, toTrackType: trackType, at: duration) { [weak self] result in
                Task { @MainActor in
                    switch result {
                    case .success:
                        self?.refreshDisplay()
                        self?.updatePlayer()
                    case .failure(let error):
                        print("Import error: \(error)")
                    }
                }
            }
        }
    }
    
    func splitAtPlayhead() {
        let affectedClipIds = engine.clips(at: currentTime).map(\.id)
        let newIds = engine.splitAllClips(at: currentTime)
        if !newIds.isEmpty {
            for clipId in affectedClipIds {
                _ = nativeEditorEngine.splitClip(id: clipId, at: currentTime.seconds)
            }
            refreshDisplay()
            updatePlayer()
        }
    }
    
    func deleteClip(_ clipId: UUID, ripple: Bool = false) {
        engine.removeClip(clipId, ripple: ripple)
        _ = nativeEditorEngine.removeClip(id: clipId)
        refreshDisplay()
        updatePlayer()
    }

    func undo() {
        engine.undo()
        refreshDisplay()
        updatePlayer()
    }

    func redo() {
        engine.redo()
        refreshDisplay()
        updatePlayer()
    }

    func addTextOverlay() {
        engine.addTextOverlay()
        refreshDisplay()
        updatePlayer()
    }

    func addDebugClip() {
        engine.addDebugClip()
        refreshDisplay()
        updatePlayer()
    }
    
    func togglePlayback() {
        if isPlaying {
            nativeEditorEngine.pause()
            player?.pause()
            isPlaying = false
        } else {
            if player == nil {
                updatePlayer()
            }
            nativeEditorEngine.play()
            player?.play()
            isPlaying = true
        }
    }
    
    func seek(to time: CMTime) {
        nativeEditorEngine.seek(to: time)
        player?.seek(to: time)
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
        duration = engine.duration
        canUndo = engine.canUndo
        canRedo = engine.canRedo
        nativeEditorEngine.configurePlayback(
            frameRate: engine.timeline.settings.frameRate,
            duration: duration
        )
        
        tracks = engine.timeline.tracks.map { track in
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
                        hasThumbnail: track.type == .video || track.type == .overlay
                    )
                },
                isMuted: track.isMuted,
                isLocked: track.isLocked
            )
        }

        nativeEditorEngine.synchronizeTimelineIncrementally(
            from: engine.timeline,
            previousSnapshot: nativeTimelineSnapshot
        )
        nativeTimelineSnapshot = nativeEditorEngine.timelineSnapshot()

        refreshCompositionFrame(at: currentTime)
    }
    
    deinit {
        if let timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
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
    
    private func updatePlayer() {
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }

        do {
            let composition = try engine.buildComposition()
            let playerItem = AVPlayerItem(asset: composition)
            
            player = AVPlayer(playerItem: playerItem)
            
            timeObserver = player?.addPeriodicTimeObserver(
                forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
                queue: .main
            ) { [weak self] time in
                self?.nativeEditorEngine.seek(to: time)
            }
        } catch {
            print("Player error: \(error)")
            player = nil
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
}
