import Foundation
import CoreMedia
import Combine

@MainActor
final class NativeEditorEngine {
    private let timelineEngine = NativeTimelineEngine()
    private let playbackEngine = PlaybackEngine()

    var timePublisher: AnyPublisher<CMTime, Never> {
        playbackEngine.timePublisher
    }

    var currentTime: CMTime {
        playbackEngine.currentTime
    }

    var isPlaying: Bool {
        playbackEngine.isPlaying
    }

    func configurePlayback(frameRate: Int, duration: CMTime) {
        playbackEngine.configure(frameRate: frameRate, duration: duration)
    }

    func play() {
        playbackEngine.play()
    }

    func pause() {
        playbackEngine.pause()
    }

    func stop() {
        playbackEngine.stop()
    }

    func seek(to time: CMTime) {
        playbackEngine.seek(to: time)
    }

    func syncTimeline(from timeline: Timeline) {
        timelineEngine.sync(from: timeline)
    }

    func synchronizeTimelineIncrementally(
        from timeline: Timeline,
        previousSnapshot: NativeTimelineSnapshot
    ) {
        let swiftTrackCount = timeline.tracks.count
        let swiftClipCount = timeline.tracks.reduce(0) { $0 + $1.clips.count }

        let needsFullResync =
            previousSnapshot.trackCount == 0 ||
            previousSnapshot.trackCount > swiftTrackCount ||
            previousSnapshot.clipCount > swiftClipCount

        if needsFullResync {
            timelineEngine.sync(from: timeline)
            return
        }

        for track in timeline.tracks {
            if !timelineEngine.hasTrack(id: track.id) {
                timelineEngine.addTrack(track)
            }

            for clip in track.clips where !timelineEngine.hasClip(id: clip.id) {
                _ = timelineEngine.addClip(clip, to: track)
            }
        }
    }

    func timelineSnapshot() -> NativeTimelineSnapshot {
        timelineEngine.snapshot()
    }

    @discardableResult
    func removeClip(id: UUID) -> Bool {
        timelineEngine.removeClip(id: id)
    }

    func splitClip(id: UUID, at time: Double) -> String? {
        timelineEngine.splitClip(id: id, at: time)
    }
}
