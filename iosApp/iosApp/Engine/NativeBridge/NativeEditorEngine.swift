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

    func ensureTrack(_ track: Track) {
        if !timelineEngine.hasTrack(id: track.id) {
            timelineEngine.addTrack(track)
        }
    }

    @discardableResult
    func ensureClip(_ clip: any ClipProtocol, in track: Track) -> Bool {
        ensureTrack(track)
        if timelineEngine.hasClip(id: clip.id) {
            return true
        }
        return timelineEngine.addClip(clip, to: track)
    }

    @discardableResult
    func addClip(
        _ clip: any ClipProtocol,
        toTrackType type: TrackType,
        named name: String
    ) -> Bool {
        let track = existingTrack(for: type) ?? Track(
            type: type,
            layer: defaultLayer(for: type),
            name: name
        )
        ensureTrack(track)
        return timelineEngine.addClip(clip, to: track)
    }

    @discardableResult
    func removeTrack(id: UUID) -> Bool {
        if let track = timelineSnapshot().tracks.first(where: { $0.id == id }),
           track.type == TrackType.video.nativeBridgeName {
            return false
        }
        return timelineEngine.removeTrack(id: id)
    }

    @discardableResult
    func setTrackMuted(id: UUID, muted: Bool) -> Bool {
        timelineEngine.setTrackMuted(id: id, muted: muted)
    }

    @discardableResult
    func setTrackLocked(id: UUID, locked: Bool) -> Bool {
        timelineEngine.setTrackLocked(id: id, locked: locked)
    }

    @discardableResult
    func removeClip(id: UUID) -> Bool {
        timelineEngine.removeClip(id: id)
    }

    @discardableResult
    func rippleDeleteClip(id: UUID) -> Bool {
        timelineEngine.rippleDeleteClip(id: id)
    }

    @discardableResult
    func moveClip(id: UUID, timelineStartSeconds: Double) -> Bool {
        timelineEngine.moveClip(id: id, timelineStartSeconds: timelineStartSeconds)
    }

    @discardableResult
    func trimClip(id: UUID, sourceStartSeconds: Double, sourceDurationSeconds: Double) -> Bool {
        timelineEngine.trimClip(
            id: id,
            sourceStartSeconds: sourceStartSeconds,
            sourceDurationSeconds: sourceDurationSeconds
        )
    }

    func splitClip(id: UUID, at time: Double) -> String? {
        timelineEngine.splitClip(id: id, at: time)
    }

    var canUndo: Bool {
        timelineEngine.canUndo
    }

    var canRedo: Bool {
        timelineEngine.canRedo
    }

    @discardableResult
    func undo() -> Bool {
        timelineEngine.undo()
    }

    @discardableResult
    func redo() -> Bool {
        timelineEngine.redo()
    }

    private func existingTrack(for type: TrackType) -> Track? {
        timelineSnapshot().tracks.first { $0.type == type.nativeBridgeName }.flatMap { snapshot in
            Track(
                id: snapshot.id,
                type: type,
                layer: TrackLayer(rawValue: snapshot.layer) ?? defaultLayer(for: type),
                name: snapshot.name,
                isMuted: snapshot.muted,
                isLocked: snapshot.locked
            )
        }
    }

    private func defaultLayer(for type: TrackType) -> TrackLayer {
        switch type {
        case .video:
            return .videoMain
        case .audio:
            return .audioMusic
        case .text:
            return .textOverlay
        case .overlay:
            return .videoOverlay
        case .effect:
            return .effectGlobal
        }
    }
}
