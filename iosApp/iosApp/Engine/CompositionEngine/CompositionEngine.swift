import Foundation
import CoreMedia
import CoreGraphics

protocol CompositionEngineProtocol {
    func evaluate(timeline: Timeline, at time: CMTime) -> CompositionFrame
}

struct CompositionEngine: CompositionEngineProtocol {
    func evaluate(timeline: Timeline, at time: CMTime) -> CompositionFrame {
        let hasSoloAudioTrack = timeline.tracks.contains { $0.type == .audio && $0.isSolo }
        let visualClips = timeline.tracks
            .sorted { $0.layer < $1.layer }
            .flatMap { track in
                activeVisualClips(in: track, at: time)
            }

        let audioClips = timeline.tracks
            .filter { track in
                guard track.type == .audio, !track.isMuted else {
                    return false
                }
                return !hasSoloAudioTrack || track.isSolo
            }
            .flatMap { track in
                activeAudioClips(in: track, at: time)
            }

        return CompositionFrame(
            timelineTimeSeconds: time.seconds,
            outputSize: timeline.settings.canvasSize,
            frameRate: timeline.settings.frameRate,
            visualClips: visualClips,
            audioClips: audioClips
        )
    }
}

private extension CompositionEngine {
    func activeVisualClips(in track: Track, at time: CMTime) -> [VisualClipSnapshot] {
        guard track.type == .video || track.type == .overlay || track.type == .text else {
            return []
        }

        return track.clips
            .filter { $0.isEnabled && $0.timelineRange.containsTime(time) }
            .compactMap { clip in
                visualSnapshot(for: clip, in: track, at: time)
            }
    }

    func activeAudioClips(in track: Track, at time: CMTime) -> [AudioClipSnapshot] {
        track.clips
            .filter { $0.isEnabled && $0.timelineRange.containsTime(time) }
            .compactMap { clip in
                guard let audioClip = clip as? AudioClip else {
                    return nil
                }

                return AudioClipSnapshot(
                    id: audioClip.id,
                    trackId: track.id,
                    timelineRange: audioClip.timelineRange,
                    sourceStartSeconds: audioClip.sourceRange.start.seconds,
                    sourceTimeSeconds: sourceTime(for: audioClip, timelineTime: time).seconds,
                    sourceURL: audioClip.sourceUrl,
                    volume: audioClip.volume,
                    trackVolume: track.volume,
                    effectiveVolume: max(audioClip.volume * track.volume, 0),
                    isMuted: track.isMuted,
                    isTrackSolo: track.isSolo
                )
            }
    }

    func visualSnapshot(
        for clip: any ClipProtocol,
        in track: Track,
        at time: CMTime
    ) -> VisualClipSnapshot? {
        switch clip {
        case let videoClip as VideoClip:
            return VisualClipSnapshot(
                id: videoClip.id,
                trackId: track.id,
                trackLayer: track.layer,
                timelineRange: videoClip.timelineRange,
                sourceTimeSeconds: sourceTime(for: videoClip, timelineTime: time).seconds,
                playbackRate: videoClip.clampedSpeed,
                sourceURL: videoClip.sourceUrl,
                kind: .video,
                transform: CompositionTransform(
                    position: videoClip.transform.position,
                    scale: videoClip.transform.scale,
                    rotationDegrees: Double(videoClip.transform.rotation) * 180 / .pi,
                    opacity: 1,
                    cropRect: videoClip.transform.cropRect,
                    scaleMode: .fit
                ),
                text: nil,
                textStyle: nil
            )
        case let overlayClip as OverlayClip:
            return VisualClipSnapshot(
                id: overlayClip.id,
                trackId: track.id,
                trackLayer: track.layer,
                timelineRange: overlayClip.timelineRange,
                sourceTimeSeconds: sourceTime(for: overlayClip, timelineTime: time).seconds,
                playbackRate: 1.0,
                sourceURL: overlayClip.sourceUrl,
                kind: .overlay,
                transform: CompositionTransform(
                    position: overlayClip.transform.position,
                    scale: overlayClip.transform.scale,
                    rotationDegrees: Double(overlayClip.transform.rotation) * 180 / .pi,
                    opacity: Double(overlayClip.opacity),
                    cropRect: overlayClip.transform.cropRect,
                    scaleMode: .fit
                ),
                text: nil,
                textStyle: nil
            )
        case let textClip as TextClip:
            return VisualClipSnapshot(
                id: textClip.id,
                trackId: track.id,
                trackLayer: track.layer,
                timelineRange: textClip.timelineRange,
                sourceTimeSeconds: sourceTime(for: textClip, timelineTime: time).seconds,
                playbackRate: 1.0,
                sourceURL: nil,
                kind: .text,
                transform: CompositionTransform(
                    position: textClip.position,
                    scale: CGSize(width: 1, height: 1),
                    rotationDegrees: 0,
                    opacity: 1,
                    cropRect: nil,
                    scaleMode: .fit
                ),
                text: textClip.text,
                textStyle: textClip.style
            )
        default:
            return nil
        }
    }

    func sourceTime(for clip: any ClipProtocol, timelineTime: CMTime) -> CMTime {
        let localTime = Swift.max(.zero, timelineTime - clip.timelineRange.start)

        switch clip {
        case let videoClip as VideoClip:
            return videoClip.sourceRange.start + CMTime(
                seconds: localTime.seconds * videoClip.clampedSpeed,
                preferredTimescale: 600
            )
        case let audioClip as AudioClip:
            return audioClip.sourceRange.start + localTime
        case let overlayClip as OverlayClip:
            return overlayClip.sourceRange.start + localTime
        case let textClip as TextClip:
            return textClip.sourceRange.start + localTime
        default:
            return clip.sourceRange.start
        }
    }
}
