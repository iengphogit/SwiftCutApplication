import Foundation
import CoreGraphics

struct NativeAudioTrackState: Identifiable, Equatable {
    let id: UUID
    let type: TrackType
    let muted: Bool
    let volume: Double
    let solo: Bool
    let locked: Bool
    let clipCount: Int
}

struct NativeAudioTransportClip: Identifiable, Equatable {
    let id: UUID
    let trackId: UUID
    let sourcePath: String
    let sourceStartSeconds: Double
    let timelineStartSeconds: Double
    let timelineDurationSeconds: Double
    let volume: Double
    let trackVolume: Double
    let effectiveVolume: Double
    let muted: Bool
    let trackSolo: Bool

    var payload: [AnyHashable: Any] {
        [
            "clipId": id.uuidString,
            "trackId": trackId.uuidString,
            "sourcePath": sourcePath,
            "sourceStartSeconds": sourceStartSeconds,
            "timelineStartSeconds": timelineStartSeconds,
            "timelineDurationSeconds": timelineDurationSeconds,
            "volume": effectiveVolume,
            "clipVolume": volume,
            "trackVolume": trackVolume,
            "muted": muted
        ]
    }

    var signatureComponent: String {
        "\(id.uuidString)|\(sourcePath)|\(sourceStartSeconds)|\(timelineStartSeconds)|\(timelineDurationSeconds)|\(volume)|\(trackVolume)|\(effectiveVolume)|\(muted)|\(trackSolo)"
    }
}

struct NativeAudioMixState: Equatable {
    let tracks: [NativeAudioTrackState]
    let clips: [NativeAudioTransportClip]

    var payloads: [[AnyHashable: Any]] {
        clips.map(\.payload)
    }

    var signature: String {
        let trackSignature = tracks
            .map { "\($0.id.uuidString)|\($0.type.rawValue)|\($0.muted)|\($0.volume)|\($0.solo)|\($0.locked)|\($0.clipCount)" }
            .joined(separator: "#")
        let clipSignature = clips.map(\.signatureComponent).joined(separator: ",")
        return "\(trackSignature)||\(clipSignature)"
    }
}

enum NativeAudioTimelineEdit: Equatable {
    case split(clipId: UUID, timeSeconds: Double)
    case trim(clipId: UUID, sourceStartSeconds: Double, sourceDurationSeconds: Double)
    case move(clipId: UUID, timelineStartSeconds: Double)
    case delete(clipId: UUID, ripple: Bool)
    case setClipVolume(clipId: UUID, volume: Double)
    case setClipMuted(clipId: UUID, muted: Bool)
    case setTrackMuted(trackId: UUID, muted: Bool)
    case setTrackVolume(trackId: UUID, volume: Double)
    case setTrackSolo(trackId: UUID, solo: Bool)
}

protocol NativeAudioEngineProtocol {
    func mixState(from compositionFrame: CompositionFrame?, timeline: Timeline?) -> NativeAudioMixState
    func transportClips(from compositionFrame: CompositionFrame?) -> [NativeAudioTransportClip]
    func transportPayloads(from compositionFrame: CompositionFrame?) -> [[AnyHashable: Any]]
    func transportSignature(from compositionFrame: CompositionFrame?) -> String
    func applying(_ edit: NativeAudioTimelineEdit, to state: NativeAudioMixState) -> NativeAudioMixState
    func prewarmWaveform(for sourcePath: String, targetBarCount: Int) async
    func waveformSamples(for sourcePath: String, targetBarCount: Int) async -> [CGFloat]
    func hasAudioTrack(for sourcePath: String) async -> Bool
}

actor NativeAudioEngine: NativeAudioEngineProtocol {
    static let shared = NativeAudioEngine()

    private let waveformAnalysisService: WaveformAnalysisServing = WaveformAnalysisService.shared

    nonisolated func mixState(from compositionFrame: CompositionFrame?, timeline: Timeline?) -> NativeAudioMixState {
        let trackStates = timeline?.tracks
            .filter { $0.type == .audio || $0.type == .video }
            .map {
                NativeAudioTrackState(
                    id: $0.id,
                    type: $0.type,
                    muted: $0.isMuted,
                    volume: Double($0.volume),
                    solo: $0.isSolo,
                    locked: $0.isLocked,
                    clipCount: $0.clips.count
                )
            } ?? []

        return NativeAudioMixState(
            tracks: trackStates,
            clips: transportClips(from: compositionFrame)
        )
    }

    nonisolated func transportClips(from compositionFrame: CompositionFrame?) -> [NativeAudioTransportClip] {
        guard let compositionFrame else {
            return []
        }

        return compositionFrame.audioClips.map { clip in
            return NativeAudioTransportClip(
                id: clip.id,
                trackId: clip.trackId,
                sourcePath: clip.sourceURL.path,
                sourceStartSeconds: clip.sourceStartSeconds,
                timelineStartSeconds: clip.timelineRange.start.seconds,
                timelineDurationSeconds: clip.timelineRange.duration.seconds,
                volume: Double(clip.volume),
                trackVolume: Double(clip.trackVolume),
                effectiveVolume: Double(clip.effectiveVolume),
                muted: clip.isMuted,
                trackSolo: clip.isTrackSolo
            )
        }
    }

    nonisolated func transportPayloads(from compositionFrame: CompositionFrame?) -> [[AnyHashable: Any]] {
        transportClips(from: compositionFrame).map(\.payload)
    }

    nonisolated func transportSignature(from compositionFrame: CompositionFrame?) -> String {
        NativeAudioMixState(tracks: [], clips: transportClips(from: compositionFrame)).signature
    }

    nonisolated func applying(_ edit: NativeAudioTimelineEdit, to state: NativeAudioMixState) -> NativeAudioMixState {
        var tracks = state.tracks
        var clips = state.clips

        switch edit {
        case let .split(clipId, _):
            if let clip = clips.first(where: { $0.id == clipId }) {
                let duplicate = NativeAudioTransportClip(
                    id: UUID(),
                    trackId: clip.trackId,
                    sourcePath: clip.sourcePath,
                    sourceStartSeconds: clip.sourceStartSeconds,
                    timelineStartSeconds: clip.timelineStartSeconds,
                    timelineDurationSeconds: clip.timelineDurationSeconds,
                    volume: clip.volume,
                    trackVolume: clip.trackVolume,
                    effectiveVolume: clip.effectiveVolume,
                    muted: clip.muted,
                    trackSolo: clip.trackSolo
                )
                clips.append(duplicate)
            }
        case let .trim(clipId, sourceStartSeconds, sourceDurationSeconds):
            clips = clips.map { clip in
                guard clip.id == clipId else { return clip }
                return NativeAudioTransportClip(
                    id: clip.id,
                    trackId: clip.trackId,
                    sourcePath: clip.sourcePath,
                    sourceStartSeconds: sourceStartSeconds,
                    timelineStartSeconds: clip.timelineStartSeconds,
                    timelineDurationSeconds: sourceDurationSeconds,
                    volume: clip.volume,
                    trackVolume: clip.trackVolume,
                    effectiveVolume: max(clip.trackVolume * clip.volume, 0),
                    muted: clip.muted,
                    trackSolo: clip.trackSolo
                )
            }
        case let .move(clipId, _):
            clips = clips.map { $0.id == clipId ? $0 : $0 }
        case let .delete(clipId, _):
            clips.removeAll { $0.id == clipId }
        case let .setClipVolume(clipId, volume):
            clips = clips.map { clip in
                guard clip.id == clipId else { return clip }
                return NativeAudioTransportClip(
                    id: clip.id,
                    trackId: clip.trackId,
                    sourcePath: clip.sourcePath,
                    sourceStartSeconds: clip.sourceStartSeconds,
                    timelineStartSeconds: clip.timelineStartSeconds,
                    timelineDurationSeconds: clip.timelineDurationSeconds,
                    volume: max(volume, 0),
                    trackVolume: clip.trackVolume,
                    effectiveVolume: max(clip.trackVolume * max(volume, 0), 0),
                    muted: clip.muted,
                    trackSolo: clip.trackSolo
                )
            }
        case let .setClipMuted(clipId, muted):
            clips = clips.map { clip in
                guard clip.id == clipId else { return clip }
                return NativeAudioTransportClip(
                    id: clip.id,
                    trackId: clip.trackId,
                    sourcePath: clip.sourcePath,
                    sourceStartSeconds: clip.sourceStartSeconds,
                    timelineStartSeconds: clip.timelineStartSeconds,
                    timelineDurationSeconds: clip.timelineDurationSeconds,
                    volume: clip.volume,
                    trackVolume: clip.trackVolume,
                    effectiveVolume: clip.effectiveVolume,
                    muted: muted,
                    trackSolo: clip.trackSolo
                )
            }
        case let .setTrackMuted(trackId, muted):
            tracks = tracks.map { track in
                guard track.id == trackId else { return track }
                return NativeAudioTrackState(
                    id: track.id,
                    type: track.type,
                    muted: muted,
                    volume: track.volume,
                    solo: track.solo,
                    locked: track.locked,
                    clipCount: track.clipCount
                )
            }
            clips = clips.map { clip in
                guard clip.trackId == trackId else { return clip }
                return NativeAudioTransportClip(
                    id: clip.id,
                    trackId: clip.trackId,
                    sourcePath: clip.sourcePath,
                    sourceStartSeconds: clip.sourceStartSeconds,
                    timelineStartSeconds: clip.timelineStartSeconds,
                    timelineDurationSeconds: clip.timelineDurationSeconds,
                    volume: clip.volume,
                    trackVolume: clip.trackVolume,
                    effectiveVolume: clip.effectiveVolume,
                    muted: muted,
                    trackSolo: clip.trackSolo
                )
            }
        case let .setTrackVolume(trackId, volume):
            let resolvedVolume = max(volume, 0)
            tracks = tracks.map { track in
                guard track.id == trackId else { return track }
                return NativeAudioTrackState(
                    id: track.id,
                    type: track.type,
                    muted: track.muted,
                    volume: resolvedVolume,
                    solo: track.solo,
                    locked: track.locked,
                    clipCount: track.clipCount
                )
            }
            clips = clips.map { clip in
                guard clip.trackId == trackId else { return clip }
                return NativeAudioTransportClip(
                    id: clip.id,
                    trackId: clip.trackId,
                    sourcePath: clip.sourcePath,
                    sourceStartSeconds: clip.sourceStartSeconds,
                    timelineStartSeconds: clip.timelineStartSeconds,
                    timelineDurationSeconds: clip.timelineDurationSeconds,
                    volume: clip.volume,
                    trackVolume: resolvedVolume,
                    effectiveVolume: max(clip.volume * resolvedVolume, 0),
                    muted: clip.muted,
                    trackSolo: clip.trackSolo
                )
            }
        case let .setTrackSolo(trackId, solo):
            tracks = tracks.map { track in
                guard track.id == trackId else { return track }
                return NativeAudioTrackState(
                    id: track.id,
                    type: track.type,
                    muted: track.muted,
                    volume: track.volume,
                    solo: solo,
                    locked: track.locked,
                    clipCount: track.clipCount
                )
            }
            clips = clips.map { clip in
                guard clip.trackId == trackId else { return clip }
                return NativeAudioTransportClip(
                    id: clip.id,
                    trackId: clip.trackId,
                    sourcePath: clip.sourcePath,
                    sourceStartSeconds: clip.sourceStartSeconds,
                    timelineStartSeconds: clip.timelineStartSeconds,
                    timelineDurationSeconds: clip.timelineDurationSeconds,
                    volume: clip.volume,
                    trackVolume: clip.trackVolume,
                    effectiveVolume: clip.effectiveVolume,
                    muted: clip.muted,
                    trackSolo: solo
                )
            }
        }

        return NativeAudioMixState(tracks: tracks, clips: clips)
    }

    func prewarmWaveform(for sourcePath: String, targetBarCount: Int) async {
        _ = await waveformSamples(for: sourcePath, targetBarCount: targetBarCount)
    }

    func waveformSamples(for sourcePath: String, targetBarCount: Int) async -> [CGFloat] {
        await waveformAnalysisService.waveformSamples(
            for: sourcePath,
            targetBarCount: targetBarCount
        )
    }

    func hasAudioTrack(for sourcePath: String) async -> Bool {
        await waveformAnalysisService.hasAudioTrack(for: sourcePath)
    }
}
