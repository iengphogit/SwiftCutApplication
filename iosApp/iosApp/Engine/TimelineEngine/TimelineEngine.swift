import Foundation
import AVFoundation
import CoreMedia
import Combine

protocol TimelineEngineProtocol: AnyObject {
    var timeline: Timeline { get }
    var duration: CMTime { get }
    var currentTime: CMTime { get set }
    var isPlaying: Bool { get }
    var canUndo: Bool { get }
    var canRedo: Bool { get }
    
    var timelinePublisher: AnyPublisher<Timeline, Never> { get }
    var timePublisher: AnyPublisher<CMTime, Never> { get }
    
    func setTimeline(_ timeline: Timeline)
    
    @discardableResult func addClip(_ clip: any ClipProtocol, to trackId: UUID, at time: CMTime?) -> UUID
    func removeClip(_ clipId: UUID)
    func removeClip(_ clipId: UUID, ripple: Bool)
    func moveClip(_ clipId: UUID, to time: CMTime)
    func trimClip(_ clipId: UUID, sourceRange: CMTimeRange)
    @discardableResult func splitClip(_ clipId: UUID, at time: CMTime) -> UUID?
    
    @discardableResult func addTrack(_ type: TrackType, name: String) -> UUID
    func removeTrack(_ trackId: UUID)
    func muteTrack(_ trackId: UUID, muted: Bool)
    func setTrackVolume(_ trackId: UUID, volume: Float)
    func setTrackSolo(_ trackId: UUID, solo: Bool)
    func lockTrack(_ trackId: UUID, locked: Bool)
    func setClipVolume(_ clipId: UUID, volume: Float)
    func setClipMuted(_ clipId: UUID, muted: Bool)
    
    func buildComposition() throws -> AVMutableComposition
    func clips(at time: CMTime) -> [any ClipProtocol]
    func undo()
    func redo()
}

final class TimelineEngine: TimelineEngineProtocol {
    private(set) var timeline: Timeline {
        didSet { timelineSubject.send(timeline) }
    }
    
    private var currentTimeValue: CMTime = .zero {
        didSet { timeSubject.send(currentTimeValue) }
    }
    
    private var isPlayingValue: Bool = false
    
    private let timelineSubject = CurrentValueSubject<Timeline, Never>(Timeline(name: "Empty"))
    private let timeSubject = CurrentValueSubject<CMTime, Never>(.zero)
    
    private var undoStack: [Timeline] = []
    private var redoStack: [Timeline] = []
    
    var duration: CMTime { timeline.duration }
    var currentTime: CMTime {
        get { currentTimeValue }
        set { currentTimeValue = newValue }
    }
    var isPlaying: Bool { isPlayingValue }
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    
    var timelinePublisher: AnyPublisher<Timeline, Never> { timelineSubject.eraseToAnyPublisher() }
    var timePublisher: AnyPublisher<CMTime, Never> { timeSubject.eraseToAnyPublisher() }
    
    init(timeline: Timeline = Timeline(name: "Empty")) {
        self.timeline = timeline
        timelineSubject.send(timeline)
    }
    
    func setTimeline(_ timeline: Timeline) {
        self.timeline = timeline
        undoStack.removeAll()
        redoStack.removeAll()
        timelineSubject.send(timeline)
    }
    
    @discardableResult
    func addClip(_ clip: any ClipProtocol, to trackId: UUID, at time: CMTime? = nil) -> UUID {
        guard let trackIndex = timeline.tracks.firstIndex(where: { $0.id == trackId }) else {
            return clip.id
        }

        let track = timeline.tracks[trackIndex]
        guard !track.isLocked, track.supports(clip: clip) else {
            return clip.id
        }
        
        var newClip = clip
        if let time = time {
            let duration = clip.timelineRange.duration
            newClip.timelineRange = CMTimeRangeMake(start: time, duration: duration)
        }

        applyEdit { timeline in
            newClip = clipWithResolvedOverlap(
                newClip,
                against: timeline.tracks[trackIndex].clips
            )
            timeline.tracks[trackIndex].clips.append(newClip)
            timeline.tracks[trackIndex].clips.sort { $0.timelineRange.start < $1.timelineRange.start }
        }

        return newClip.id
    }

    @discardableResult
    func addClip(
        _ clip: any ClipProtocol,
        toTrackType type: TrackType,
        named name: String,
        at time: CMTime? = nil
    ) -> UUID {
        var newClip = clip
        if let time = time {
            newClip = clipWithTimelineRange(
                newClip,
                timelineRange: CMTimeRangeMake(start: time, duration: clip.timelineRange.duration)
            )
        }

        guard trackType(for: newClip) == type else {
            return clip.id
        }

        applyEdit { timeline in
            let trackIndex: Int
            if let existingTrackIndex = timeline.tracks.firstIndex(where: { $0.type == type }) {
                guard !timeline.tracks[existingTrackIndex].isLocked else {
                    return
                }
                trackIndex = existingTrackIndex
            } else {
                let newTrack = Track(type: type, layer: defaultLayer(for: type), name: name)
                timeline.tracks.append(newTrack)
                timeline.tracks.sort { $0.layer < $1.layer }
                guard let createdTrackIndex = timeline.tracks.firstIndex(where: { $0.id == newTrack.id }) else {
                    return
                }
                trackIndex = createdTrackIndex
            }

            newClip = clipWithResolvedOverlap(
                newClip,
                against: timeline.tracks[trackIndex].clips
            )
            timeline.tracks[trackIndex].clips.append(newClip)
            timeline.tracks[trackIndex].clips.sort { $0.timelineRange.start < $1.timelineRange.start }
        }

        return newClip.id
    }
    
    func removeClip(_ clipId: UUID) {
        removeClip(clipId, ripple: false)
    }

    func removeClip(_ clipId: UUID, ripple: Bool) {
        guard let (trackIndex, clipIndex, clip) = locateClip(clipId) else {
            return
        }

        guard !timeline.tracks[trackIndex].isLocked else {
            return
        }

        applyEdit { timeline in
            timeline.tracks[trackIndex].clips.remove(at: clipIndex)

            guard ripple else {
                return
            }

            let rippleStart = clip.timelineRange.end
            let rippleOffset = clip.timelineRange.duration

            for index in timeline.tracks.indices where !timeline.tracks[index].isLocked {
                timeline.tracks[index].clips = timeline.tracks[index].clips.map { existingClip in
                    guard existingClip.timelineRange.start >= rippleStart else {
                        return existingClip
                    }
                    return shiftClip(existingClip, by: .zero - rippleOffset)
                }
                timeline.tracks[index].clips.sort { $0.timelineRange.start < $1.timelineRange.start }
            }
        }
    }
    
    func moveClip(_ clipId: UUID, to time: CMTime) {
        guard let (trackIndex, clipIndex, clip) = locateClip(clipId) else {
            return
        }

        guard !timeline.tracks[trackIndex].isLocked else {
            return
        }

        let clampedStartTime = max(.zero, time)

        applyEdit { timeline in
            var updatedClip = clip
            updatedClip.timelineRange = CMTimeRangeMake(
                start: clampedStartTime,
                duration: updatedClip.timelineRange.duration
            )
            updatedClip = clipWithResolvedOverlap(
                updatedClip,
                against: timeline.tracks[trackIndex].clips.filter { $0.id != clipId }
            )
            timeline.tracks[trackIndex].clips[clipIndex] = updatedClip
            timeline.tracks[trackIndex].clips.sort { $0.timelineRange.start < $1.timelineRange.start }
        }
    }
    
    func trimClip(_ clipId: UUID, sourceRange: CMTimeRange) {
        guard let (trackIndex, clipIndex, clip) = locateClip(clipId) else {
            return
        }

        guard !timeline.tracks[trackIndex].isLocked else {
            return
        }

        guard let validatedSourceRange = validatedSourceRange(sourceRange) else {
            return
        }

        applyEdit { timeline in
            var updatedClip = clip
            updatedClip.sourceRange = validatedSourceRange

            if let videoClip = updatedClip as? VideoClip {
                let effectiveDuration = videoClip.effectiveDuration
                guard effectiveDuration.isValid, effectiveDuration > .zero else {
                    return
                }
                updatedClip.timelineRange = CMTimeRangeMake(
                    start: updatedClip.timelineRange.start,
                    duration: effectiveDuration
                )
            } else {
                updatedClip.timelineRange = CMTimeRangeMake(
                    start: updatedClip.timelineRange.start,
                    duration: validatedSourceRange.duration
                )
            }

            updatedClip = clipWithResolvedOverlap(
                updatedClip,
                against: timeline.tracks[trackIndex].clips.filter { $0.id != clipId }
            )
            timeline.tracks[trackIndex].clips[clipIndex] = updatedClip
            timeline.tracks[trackIndex].clips.sort { $0.timelineRange.start < $1.timelineRange.start }
        }
    }
    
    @discardableResult
    func splitClip(_ clipId: UUID, at time: CMTime) -> UUID? {
        guard let (trackIndex, clipIndex, originalClip) = locateClip(clipId) else {
            return nil
        }

        guard !timeline.tracks[trackIndex].isLocked else {
            return nil
        }

        guard originalClip.timelineRange.start < time && time < originalClip.timelineRange.end else {
            return nil
        }

        let relativeTime = time - originalClip.timelineRange.start
        let firstPartDuration = relativeTime
        let secondPartDuration = originalClip.timelineRange.duration - relativeTime
        let sourceRatio = originalClip.timelineRange.duration.isZero
            ? 1.0
            : originalClip.sourceRange.duration.seconds / originalClip.timelineRange.duration.seconds
        let firstPartSourceDuration = CMTime(
            seconds: firstPartDuration.seconds * sourceRatio,
            preferredTimescale: 600
        )
        let secondPartSourceDuration = CMTime(
            seconds: secondPartDuration.seconds * sourceRatio,
            preferredTimescale: 600
        )

        let secondClipId: UUID
        let replacementClips: [(any ClipProtocol)]

        if let videoClip = originalClip as? VideoClip {
            let firstPart = VideoClip(
                id: videoClip.id,
                linkedClipGroupId: videoClip.linkedClipGroupId,
                sourceUrl: videoClip.sourceUrl,
                sourceRange: CMTimeRangeMake(start: videoClip.sourceRange.start, duration: firstPartSourceDuration),
                timelineRange: CMTimeRangeMake(start: videoClip.timelineRange.start, duration: firstPartDuration),
                isEnabled: videoClip.isEnabled,
                speed: videoClip.speed,
                volume: videoClip.volume,
                isMuted: videoClip.isMuted,
                transform: videoClip.transform,
                filters: videoClip.filters,
                adjustments: videoClip.adjustments,
                animations: videoClip.animations
            )

            let secondPart = VideoClip(
                id: UUID(),
                linkedClipGroupId: videoClip.linkedClipGroupId,
                sourceUrl: videoClip.sourceUrl,
                sourceRange: CMTimeRangeMake(
                    start: videoClip.sourceRange.start + firstPartSourceDuration,
                    duration: secondPartSourceDuration
                ),
                timelineRange: CMTimeRangeMake(start: time, duration: secondPartDuration),
                isEnabled: videoClip.isEnabled,
                speed: videoClip.speed,
                volume: videoClip.volume,
                isMuted: videoClip.isMuted,
                transform: videoClip.transform,
                filters: videoClip.filters,
                adjustments: videoClip.adjustments,
                animations: videoClip.animations
            )

            secondClipId = secondPart.id
            replacementClips = [firstPart, secondPart]
        } else if let audioClip = originalClip as? AudioClip {
            let firstPart = AudioClip(
                id: audioClip.id,
                linkedClipGroupId: audioClip.linkedClipGroupId,
                sourceUrl: audioClip.sourceUrl,
                sourceRange: CMTimeRangeMake(start: audioClip.sourceRange.start, duration: firstPartSourceDuration),
                timelineRange: CMTimeRangeMake(start: audioClip.timelineRange.start, duration: firstPartDuration),
                isEnabled: audioClip.isEnabled,
                volume: audioClip.volume,
                fadeInDuration: audioClip.fadeInDuration,
                fadeOutDuration: audioClip.fadeOutDuration,
                effects: audioClip.effects
            )

            let secondPart = AudioClip(
                id: UUID(),
                linkedClipGroupId: audioClip.linkedClipGroupId,
                sourceUrl: audioClip.sourceUrl,
                sourceRange: CMTimeRangeMake(
                    start: audioClip.sourceRange.start + firstPartSourceDuration,
                    duration: secondPartSourceDuration
                ),
                timelineRange: CMTimeRangeMake(start: time, duration: secondPartDuration),
                isEnabled: audioClip.isEnabled,
                volume: audioClip.volume,
                fadeInDuration: audioClip.fadeInDuration,
                fadeOutDuration: audioClip.fadeOutDuration,
                effects: audioClip.effects
            )

            secondClipId = secondPart.id
            replacementClips = [firstPart, secondPart]
        } else if let overlayClip = originalClip as? OverlayClip {
            let firstPart = OverlayClip(
                id: overlayClip.id,
                sourceUrl: overlayClip.sourceUrl,
                sourceRange: CMTimeRangeMake(start: overlayClip.sourceRange.start, duration: firstPartSourceDuration),
                timelineRange: CMTimeRangeMake(start: overlayClip.timelineRange.start, duration: firstPartDuration),
                isEnabled: overlayClip.isEnabled,
                transform: overlayClip.transform,
                blendMode: overlayClip.blendMode,
                opacity: overlayClip.opacity
            )

            let secondPart = OverlayClip(
                id: UUID(),
                sourceUrl: overlayClip.sourceUrl,
                sourceRange: CMTimeRangeMake(
                    start: overlayClip.sourceRange.start + firstPartSourceDuration,
                    duration: secondPartSourceDuration
                ),
                timelineRange: CMTimeRangeMake(start: time, duration: secondPartDuration),
                isEnabled: overlayClip.isEnabled,
                transform: overlayClip.transform,
                blendMode: overlayClip.blendMode,
                opacity: overlayClip.opacity
            )

            secondClipId = secondPart.id
            replacementClips = [firstPart, secondPart]
        } else {
            return nil
        }

        applyEdit { timeline in
            timeline.tracks[trackIndex].clips.remove(at: clipIndex)
            timeline.tracks[trackIndex].clips.append(contentsOf: replacementClips)
            timeline.tracks[trackIndex].clips.sort { $0.timelineRange.start < $1.timelineRange.start }
        }

        return secondClipId
    }
    
    @discardableResult
    func addTrack(_ type: TrackType, name: String) -> UUID {
        let track = Track(type: type, layer: defaultLayer(for: type), name: name)

        applyEdit { timeline in
            timeline.tracks.append(track)
            timeline.tracks.sort { $0.layer < $1.layer }
        }
        
        return track.id
    }
    
    func removeTrack(_ trackId: UUID) {
        guard timeline.tracks.contains(where: { $0.id == trackId }) else {
            return
        }

        applyEdit { timeline in
            timeline.tracks.removeAll { $0.id == trackId }
        }
    }
    
    func muteTrack(_ trackId: UUID, muted: Bool) {
        guard let index = timeline.tracks.firstIndex(where: { $0.id == trackId }) else {
            return
        }

        applyEdit { timeline in
            timeline.tracks[index].isMuted = muted
        }
    }

    func setTrackVolume(_ trackId: UUID, volume: Float) {
        guard let index = timeline.tracks.firstIndex(where: { $0.id == trackId }) else {
            return
        }

        applyEdit { timeline in
            timeline.tracks[index].volume = max(volume, 0)
        }
    }

    func setTrackSolo(_ trackId: UUID, solo: Bool) {
        guard let index = timeline.tracks.firstIndex(where: { $0.id == trackId }) else {
            return
        }

        applyEdit { timeline in
            timeline.tracks[index].isSolo = solo
        }
    }
    
    func lockTrack(_ trackId: UUID, locked: Bool) {
        guard let index = timeline.tracks.firstIndex(where: { $0.id == trackId }) else {
            return
        }

        applyEdit { timeline in
            timeline.tracks[index].isLocked = locked
        }
    }

    func setClipVolume(_ clipId: UUID, volume: Float) {
        guard let (trackIndex, clipIndex, clip) = locateClip(clipId) else {
            return
        }

        guard !timeline.tracks[trackIndex].isLocked else {
            return
        }

        let resolvedVolume = max(volume, 0)

        applyEdit { timeline in
            switch clip {
            case var videoClip as VideoClip:
                videoClip.volume = resolvedVolume
                timeline.tracks[trackIndex].clips[clipIndex] = videoClip
            case var audioClip as AudioClip:
                audioClip.volume = resolvedVolume
                timeline.tracks[trackIndex].clips[clipIndex] = audioClip
            default:
                break
            }
        }
    }

    func setClipMuted(_ clipId: UUID, muted: Bool) {
        guard let (trackIndex, clipIndex, clip) = locateClip(clipId) else {
            return
        }

        guard !timeline.tracks[trackIndex].isLocked else {
            return
        }

        applyEdit { timeline in
            switch clip {
            case var videoClip as VideoClip:
                videoClip.isMuted = muted
                timeline.tracks[trackIndex].clips[clipIndex] = videoClip
            default:
                break
            }
        }
    }
    
    func buildComposition() throws -> AVMutableComposition {
        let composition = AVMutableComposition()
        
        for track in timeline.tracks {
            guard !track.isMuted else { continue }
            
            for clip in track.clips {
                guard clip.isEnabled else { continue }
                
                let asset = AVURLAsset(url: clipSourceUrl(clip))
                
                switch track.type {
                case .video:
                    try insertVideoTrack(clip: clip, asset: asset, into: composition)
                    if let videoClip = clip as? VideoClip, !videoClip.isMuted {
                        try insertAudioTrack(clip: clip, asset: asset, into: composition)
                    }
                case .audio:
                    try insertAudioTrack(clip: clip, asset: asset, into: composition)
                case .overlay:
                    try insertVideoTrack(clip: clip, asset: asset, into: composition)
                case .text, .effect:
                    break
                }
            }
        }
        
        return composition
    }
    
    func clips(at time: CMTime) -> [any ClipProtocol] {
        timeline.tracks.flatMap { track in
            track.clips.filter { $0.timelineRange.containsTime(time) && $0.isEnabled }
        }
    }

    func undo() {
        guard let previousTimeline = undoStack.popLast() else {
            return
        }

        redoStack.append(timeline)
        timeline = previousTimeline
    }

    func redo() {
        guard let nextTimeline = redoStack.popLast() else {
            return
        }

        undoStack.append(timeline)
        timeline = nextTimeline
    }
    
    private func clipSourceUrl(_ clip: any ClipProtocol) -> URL {
        switch clip {
        case let videoClip as VideoClip:
            return videoClip.sourceUrl
        case let audioClip as AudioClip:
            return audioClip.sourceUrl
        case let overlayClip as OverlayClip:
            return overlayClip.sourceUrl
        default:
            fatalError("Unknown clip type")
        }
    }
    
    private func insertVideoTrack(clip: any ClipProtocol, asset: AVURLAsset, into composition: AVMutableComposition) throws {
        guard let assetTrack = asset.tracks(withMediaType: .video).first else { return }
        
        let compositionTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )
        
        try compositionTrack?.insertTimeRange(
            clip.sourceRange,
            of: assetTrack,
            at: clip.timelineRange.start
        )
        
        if let videoClip = clip as? VideoClip, videoClip.speed != 1.0 {
            let insertedRange = CMTimeRangeMake(
                start: clip.timelineRange.start,
                duration: clip.sourceRange.duration
            )
            compositionTrack?.scaleTimeRange(insertedRange, toDuration: videoClip.effectiveDuration)
        }
    }
    
    private func insertAudioTrack(clip: any ClipProtocol, asset: AVURLAsset, into composition: AVMutableComposition) throws {
        guard let assetTrack = asset.tracks(withMediaType: .audio).first else { return }
        
        let compositionTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )
        
        try compositionTrack?.insertTimeRange(
            clip.sourceRange,
            of: assetTrack,
            at: clip.timelineRange.start
        )
    }

    private func applyEdit(_ mutate: (inout Timeline) -> Void) {
        undoStack.append(timeline)
        redoStack.removeAll()

        var updatedTimeline = timeline
        mutate(&updatedTimeline)
        updatedTimeline.updateModifiedAt()
        timeline = updatedTimeline
    }

    private func locateClip(_ clipId: UUID) -> (trackIndex: Int, clipIndex: Int, clip: any ClipProtocol)? {
        for trackIndex in timeline.tracks.indices {
            if let clipIndex = timeline.tracks[trackIndex].clips.firstIndex(where: { $0.id == clipId }) {
                return (trackIndex, clipIndex, timeline.tracks[trackIndex].clips[clipIndex])
            }
        }
        return nil
    }

    private func validatedSourceRange(_ sourceRange: CMTimeRange) -> CMTimeRange? {
        guard sourceRange.isValid, !sourceRange.isEmpty else {
            return nil
        }

        let clampedStart = max(.zero, sourceRange.start)
        let duration = sourceRange.duration

        guard duration.isValid, duration > .zero else {
            return nil
        }

        return CMTimeRangeMake(start: clampedStart, duration: duration)
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

    private func trackType(for clip: any ClipProtocol) -> TrackType? {
        switch clip {
        case is VideoClip:
            return .video
        case is AudioClip:
            return .audio
        case is TextClip:
            return .text
        case is OverlayClip:
            return .overlay
        default:
            return nil
        }
    }

    private func clipWithResolvedOverlap(
        _ clip: any ClipProtocol,
        against otherClips: [any ClipProtocol]
    ) -> any ClipProtocol {
        var candidateStart = max(.zero, clip.timelineRange.start)
        let duration = clip.timelineRange.duration
        let sortedClips = otherClips.sorted { $0.timelineRange.start < $1.timelineRange.start }

        for otherClip in sortedClips {
            let candidateEnd = candidateStart + duration
            let overlaps = candidateStart < otherClip.timelineRange.end &&
                candidateEnd > otherClip.timelineRange.start

            if overlaps {
                candidateStart = otherClip.timelineRange.end
            }
        }

        let resolvedRange = CMTimeRangeMake(start: candidateStart, duration: duration)
        return clipWithTimelineRange(clip, timelineRange: resolvedRange)
    }

    private func clipWithTimelineRange(
        _ clip: any ClipProtocol,
        timelineRange: CMTimeRange
    ) -> any ClipProtocol {
        switch clip {
        case var videoClip as VideoClip:
            videoClip.timelineRange = timelineRange
            return videoClip
        case var audioClip as AudioClip:
            audioClip.timelineRange = timelineRange
            return audioClip
        case var textClip as TextClip:
            textClip.timelineRange = timelineRange
            textClip.sourceRange = timelineRange
            return textClip
        case var overlayClip as OverlayClip:
            overlayClip.timelineRange = timelineRange
            return overlayClip
        default:
            return clip
        }
    }

    private func shiftClip(_ clip: any ClipProtocol, by offset: CMTime) -> any ClipProtocol {
        switch clip {
        case var videoClip as VideoClip:
            videoClip.timelineRange = CMTimeRangeMake(
                start: max(.zero, videoClip.timelineRange.start + offset),
                duration: videoClip.timelineRange.duration
            )
            return videoClip
        case var audioClip as AudioClip:
            audioClip.timelineRange = CMTimeRangeMake(
                start: max(.zero, audioClip.timelineRange.start + offset),
                duration: audioClip.timelineRange.duration
            )
            return audioClip
        case var textClip as TextClip:
            textClip.timelineRange = CMTimeRangeMake(
                start: max(.zero, textClip.timelineRange.start + offset),
                duration: textClip.timelineRange.duration
            )
            textClip.sourceRange = textClip.timelineRange
            return textClip
        case var overlayClip as OverlayClip:
            overlayClip.timelineRange = CMTimeRangeMake(
                start: max(.zero, overlayClip.timelineRange.start + offset),
                duration: overlayClip.timelineRange.duration
            )
            return overlayClip
        default:
            return clip
        }
    }
}
