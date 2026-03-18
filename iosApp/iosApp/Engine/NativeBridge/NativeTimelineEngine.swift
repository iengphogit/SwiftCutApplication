import Foundation

struct NativeTimelineSnapshot {
    let canvasWidth: Int
    let canvasHeight: Int
    let frameRate: Int
    let trackCount: Int
    let clipCount: Int
    let durationSeconds: Double
    let tracks: [NativeTrackSnapshot]
}

struct NativeTrackSnapshot: Identifiable {
    let id: UUID
    let name: String
    let type: String
    let layer: Int
    let muted: Bool
    let volume: Float
    let solo: Bool
    let locked: Bool
    let clips: [NativeClipSnapshot]
}

struct NativeClipSnapshot: Identifiable {
    let id: UUID
    let name: String
    let type: String
    let sourceStart: Double
    let sourceDuration: Double
    let timelineStart: Double
    let timelineDuration: Double
    let volume: Float
    let muted: Bool
    let sourcePath: String
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
                volume: Double(track.volume),
                solo: track.isSolo,
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
                    volume: clip.nativeVolume,
                    muted: clip.nativeMuted,
                    enabled: clip.isEnabled
                )
            }
        }

        isSynchronized = true
    }

    func snapshot() -> NativeTimelineSnapshot {
        let dictionary = bridge.snapshotDictionary()
        let trackDictionaries = dictionary["tracks"] as? [[String: Any]] ?? []
        return NativeTimelineSnapshot(
            canvasWidth: dictionary["canvasWidth"] as? Int ?? 1080,
            canvasHeight: dictionary["canvasHeight"] as? Int ?? 1920,
            frameRate: dictionary["frameRate"] as? Int ?? 30,
            trackCount: dictionary["trackCount"] as? Int ?? 0,
            clipCount: dictionary["clipCount"] as? Int ?? 0,
            durationSeconds: dictionary["durationSeconds"] as? Double ?? 0,
            tracks: trackDictionaries.compactMap(NativeTrackSnapshot.init(dictionary:))
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
            volume: Double(track.volume),
            solo: track.isSolo,
            locked: track.isLocked
        )
    }

    @discardableResult
    func removeTrack(id: UUID) -> Bool {
        guard isSynchronized else { return false }
        return bridge.removeTrack(withId: id.uuidString)
    }

    @discardableResult
    func setTrackMuted(id: UUID, muted: Bool) -> Bool {
        guard isSynchronized else { return false }
        return bridge.muteTrack(withId: id.uuidString, muted: muted)
    }

    @discardableResult
    func setTrackVolume(id: UUID, volume: Float) -> Bool {
        guard isSynchronized else { return false }
        return bridge.updateTrackVolume(withId: id.uuidString, volume: Double(max(volume, 0)))
    }

    @discardableResult
    func setTrackSolo(id: UUID, solo: Bool) -> Bool {
        guard isSynchronized else { return false }
        return bridge.updateTrackSolo(withId: id.uuidString, solo: solo)
    }

    @discardableResult
    func setTrackLocked(id: UUID, locked: Bool) -> Bool {
        guard isSynchronized else { return false }
        return bridge.lockTrack(withId: id.uuidString, locked: locked)
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
            volume: clip.nativeVolume,
            muted: clip.nativeMuted,
            enabled: clip.isEnabled
        )
    }

    @discardableResult
    func setClipVolume(id: UUID, volume: Float) -> Bool {
        guard isSynchronized else { return false }
        return bridge.updateClipVolume(withId: id.uuidString, volume: Double(max(volume, 0)))
    }

    @discardableResult
    func setClipMuted(id: UUID, muted: Bool) -> Bool {
        guard isSynchronized else { return false }
        return bridge.updateClipMuted(withId: id.uuidString, muted: muted)
    }

    @discardableResult
    func removeClip(id: UUID) -> Bool {
        guard isSynchronized else { return false }
        return bridge.removeClip(withId: id.uuidString)
    }

    @discardableResult
    func rippleDeleteClip(id: UUID) -> Bool {
        guard isSynchronized else { return false }
        return bridge.rippleDeleteClip(withId: id.uuidString)
    }

    @discardableResult
    func moveClip(id: UUID, timelineStartSeconds: Double) -> Bool {
        guard isSynchronized else { return false }
        return bridge.moveClip(withId: id.uuidString, timelineStartSeconds: timelineStartSeconds)
    }

    @discardableResult
    func trimClip(id: UUID, sourceStartSeconds: Double, sourceDurationSeconds: Double) -> Bool {
        guard isSynchronized else { return false }
        return bridge.trimClip(
            withId: id.uuidString,
            sourceStartSeconds: sourceStartSeconds,
            sourceDurationSeconds: sourceDurationSeconds
        )
    }

    func splitClip(id: UUID, at time: Double) -> String? {
        guard isSynchronized else { return nil }
        return bridge.splitClip(withId: id.uuidString, splitTimeSeconds: time)
    }

    var canUndo: Bool {
        guard isSynchronized else { return false }
        return bridge.canUndo()
    }

    var canRedo: Bool {
        guard isSynchronized else { return false }
        return bridge.canRedo()
    }

    @discardableResult
    func undo() -> Bool {
        guard isSynchronized else { return false }
        return bridge.undo()
    }

    @discardableResult
    func redo() -> Bool {
        guard isSynchronized else { return false }
        return bridge.redo()
    }
}

private extension NativeTrackSnapshot {
    init?(dictionary: [String: Any]) {
        guard
            let idString = dictionary["id"] as? String,
            let id = UUID(uuidString: idString),
            let name = dictionary["name"] as? String,
            let type = dictionary["type"] as? String,
            let layer = dictionary["layer"] as? Int,
            let muted = dictionary["muted"] as? Bool,
            let locked = dictionary["locked"] as? Bool
        else {
            return nil
        }

        let clipDictionaries = dictionary["clips"] as? [[String: Any]] ?? []
        self.id = id
        self.name = name
        self.type = type
        self.layer = layer
        self.muted = muted
        if let volume = dictionary["volume"] as? Float {
            self.volume = volume
        } else if let volume = dictionary["volume"] as? Double {
            self.volume = Float(volume)
        } else {
            self.volume = 1.0
        }
        self.solo = dictionary["solo"] as? Bool ?? false
        self.locked = locked
        self.clips = clipDictionaries.compactMap(NativeClipSnapshot.init(dictionary:))
    }
}

private extension NativeClipSnapshot {
    init?(dictionary: [String: Any]) {
        guard
            let idString = dictionary["id"] as? String,
            let id = UUID(uuidString: idString),
            let name = dictionary["name"] as? String,
            let type = dictionary["type"] as? String,
            let sourceStart = dictionary["sourceStart"] as? Double,
            let sourceDuration = dictionary["sourceDuration"] as? Double,
            let timelineStart = dictionary["timelineStart"] as? Double,
            let timelineDuration = dictionary["timelineDuration"] as? Double
        else {
            return nil
        }

        self.id = id
        self.name = name
        self.type = type
        self.sourceStart = sourceStart
        self.sourceDuration = sourceDuration
        self.timelineStart = timelineStart
        self.timelineDuration = timelineDuration
        if let volume = dictionary["volume"] as? Float {
            self.volume = volume
        } else if let volume = dictionary["volume"] as? Double {
            self.volume = Float(volume)
        } else {
            self.volume = 1.0
        }
        self.muted = dictionary["muted"] as? Bool ?? false
        self.sourcePath = dictionary["sourcePath"] as? String ?? ""
    }
}

private extension ClipProtocol {
    var nativeVolume: Double {
        switch self {
        case let videoClip as VideoClip:
            return Double(videoClip.volume)
        case let audioClip as AudioClip:
            return Double(audioClip.volume)
        default:
            return 1.0
        }
    }

    var nativeMuted: Bool {
        switch self {
        case let videoClip as VideoClip:
            return videoClip.isMuted
        default:
            return false
        }
    }
}

extension TrackType {
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

extension ClipProtocol {
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
