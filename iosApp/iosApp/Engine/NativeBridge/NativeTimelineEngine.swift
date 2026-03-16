import Foundation

struct NativeTimelineSnapshot {
    let trackCount: Int
    let clipCount: Int
    let durationSeconds: Double
}

@MainActor
final class NativeTimelineEngine {
    private let bridge = SCNativeTimelineBridge()
    private var isSynchronized = false

    func sync(from timeline: Timeline) {
        bridge.reset(
            withCanvasWidth: Int(timeline.settings.canvasSize.width),
            canvasHeight: Int(timeline.settings.canvasSize.height),
            frameRate: timeline.settings.frameRate
        )

        for track in timeline.tracks {
            bridge.addTrack(
                withId: track.id.uuidString,
                name: track.name,
                type: track.type.nativeBridgeName,
                layer: track.layer.rawValue,
                muted: track.isMuted,
                locked: track.isLocked
            )

            for clip in track.clips {
                _ = bridge.addClipToTrack(
                    withId: track.id.uuidString,
                    clipId: clip.id.uuidString,
                    name: clip.nativeDisplayName,
                    type: track.type.nativeBridgeName,
                    sourcePath: clip.nativeSourcePath,
                    sourceStart: clip.sourceRange.start.seconds,
                    sourceDuration: clip.sourceRange.duration.seconds,
                    timelineStart: clip.timelineRange.start.seconds,
                    timelineDuration: clip.timelineRange.duration.seconds,
                    speed: clip.nativeSpeed,
                    enabled: clip.isEnabled
                )
            }
        }

        isSynchronized = true
    }

    func snapshot() -> NativeTimelineSnapshot {
        let dictionary = bridge.snapshotDictionary()
        return NativeTimelineSnapshot(
            trackCount: dictionary["trackCount"] as? Int ?? 0,
            clipCount: dictionary["clipCount"] as? Int ?? 0,
            durationSeconds: dictionary["durationSeconds"] as? Double ?? 0
        )
    }

    func hasTrack(id: UUID) -> Bool {
        guard isSynchronized else { return false }
        return bridge.hasTrack(withId: id.uuidString)
    }

    func hasClip(id: UUID) -> Bool {
        guard isSynchronized else { return false }
        return bridge.hasClip(withId: id.uuidString)
    }

    func addTrack(_ track: Track) {
        if !isSynchronized {
            return
        }

        bridge.addTrack(
            withId: track.id.uuidString,
            name: track.name,
            type: track.type.nativeBridgeName,
            layer: track.layer.rawValue,
            muted: track.isMuted,
            locked: track.isLocked
        )
    }

    @discardableResult
    func addClip(_ clip: any ClipProtocol, to track: Track) -> Bool {
        guard isSynchronized else { return false }

        if !hasTrack(id: track.id) {
            addTrack(track)
        }

        return bridge.addClipToTrack(
            withId: track.id.uuidString,
            clipId: clip.id.uuidString,
            name: clip.nativeDisplayName,
            type: track.type.nativeBridgeName,
            sourcePath: clip.nativeSourcePath,
            sourceStart: clip.sourceRange.start.seconds,
            sourceDuration: clip.sourceRange.duration.seconds,
            timelineStart: clip.timelineRange.start.seconds,
            timelineDuration: clip.timelineRange.duration.seconds,
            speed: clip.nativeSpeed,
            enabled: clip.isEnabled
        )
    }

    @discardableResult
    func removeClip(id: UUID) -> Bool {
        guard isSynchronized else { return false }
        return bridge.removeClip(withId: id.uuidString)
    }

    func splitClip(id: UUID, at time: Double) -> String? {
        guard isSynchronized else { return nil }
        return bridge.splitClip(withId: id.uuidString, splitTimeSeconds: time)
    }
}

private extension TrackType {
    var nativeBridgeName: String {
        switch self {
        case .video:
            return "video"
        case .audio:
            return "audio"
        case .text:
            return "text"
        case .overlay:
            return "overlay"
        case .effect:
            return "effect"
        }
    }
}

private extension ClipProtocol {
    var nativeDisplayName: String {
        switch self {
        case let textClip as TextClip:
            return textClip.text
        case is AudioClip:
            return "Audio"
        case is OverlayClip:
            return "Overlay"
        default:
            return "Video"
        }
    }

    var nativeSourcePath: String? {
        switch self {
        case let videoClip as VideoClip:
            return videoClip.sourceUrl.path
        case let audioClip as AudioClip:
            return audioClip.sourceUrl.path
        case let overlayClip as OverlayClip:
            return overlayClip.sourceUrl.path
        default:
            return nil
        }
    }

    var nativeSpeed: Double {
        if let videoClip = self as? VideoClip {
            return videoClip.clampedSpeed
        }
        return 1.0
    }
}
