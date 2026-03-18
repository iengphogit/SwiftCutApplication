import Foundation
import CoreMedia
import CoreGraphics

protocol ClipProtocol: Identifiable, Codable {
    var id: UUID { get }
    var sourceRange: CMTimeRange { get set }
    var timelineRange: CMTimeRange { get set }
    var isEnabled: Bool { get set }
}

extension ClipProtocol {
    var hasSource: Bool { true }
}

struct CMTimeRangeWrapper: Codable {
    let startSeconds: Double
    let durationSeconds: Double
    let timescale: Int32
    
    init(_ range: CMTimeRange) {
        self.startSeconds = range.start.seconds
        self.durationSeconds = range.duration.seconds
        self.timescale = range.start.timescale
    }
    
    var cmTimeRange: CMTimeRange {
        let start = CMTime(seconds: startSeconds, preferredTimescale: timescale)
        let duration = CMTime(seconds: durationSeconds, preferredTimescale: timescale)
        return CMTimeRangeMake(start: start, duration: duration)
    }
}

extension CMTimeRange: Codable {
    public init(from decoder: Decoder) throws {
        let wrapper = try CMTimeRangeWrapper(from: decoder)
        self = wrapper.cmTimeRange
    }
    
    public func encode(to encoder: Encoder) throws {
        try CMTimeRangeWrapper(self).encode(to: encoder)
    }
}

struct VideoClip: ClipProtocol {
    let id: UUID
    var linkedClipGroupId: UUID?
    var sourceUrl: URL
    var sourceRange: CMTimeRange
    var timelineRange: CMTimeRange
    var isEnabled: Bool
    
    var speed: Double
    var volume: Float
    var isMuted: Bool
    var transform: ClipTransform
    var filters: [Filter]
    var adjustments: ColorAdjustments
    var animations: [KeyframeAnimation]

    var clampedSpeed: Double {
        max(speed, 0.1)
    }
    
    var effectiveDuration: CMTime {
        CMTime(
            seconds: sourceRange.duration.seconds / clampedSpeed,
            preferredTimescale: sourceRange.duration.timescale == 0 ? 600 : sourceRange.duration.timescale
        )
    }
    
    init(
        id: UUID = UUID(),
        linkedClipGroupId: UUID? = nil,
        sourceUrl: URL,
        sourceRange: CMTimeRange,
        timelineRange: CMTimeRange? = nil,
        isEnabled: Bool = true,
        speed: Double = 1.0,
        volume: Float = 1.0,
        isMuted: Bool = false,
        transform: ClipTransform = .identity,
        filters: [Filter] = [],
        adjustments: ColorAdjustments = .default,
        animations: [KeyframeAnimation] = []
    ) {
        self.id = id
        self.linkedClipGroupId = linkedClipGroupId
        self.sourceUrl = sourceUrl
        self.sourceRange = sourceRange
        self.timelineRange = timelineRange ?? CMTimeRangeMake(start: .zero, duration: sourceRange.duration)
        self.isEnabled = isEnabled
        self.speed = speed
        self.volume = volume
        self.isMuted = isMuted
        self.transform = transform
        self.filters = filters
        self.adjustments = adjustments
        self.animations = animations
    }
}

struct AudioClip: ClipProtocol {
    let id: UUID
    var linkedClipGroupId: UUID?
    var sourceUrl: URL
    var sourceRange: CMTimeRange
    var timelineRange: CMTimeRange
    var isEnabled: Bool
    
    var volume: Float
    var fadeInDurationSeconds: Double
    var fadeOutDurationSeconds: Double
    private var effectWrappers: [AudioEffectWrapper]
    
    var fadeInDuration: CMTime {
        get { CMTime(seconds: fadeInDurationSeconds, preferredTimescale: 600) }
        set { fadeInDurationSeconds = newValue.seconds }
    }
    
    var fadeOutDuration: CMTime {
        get { CMTime(seconds: fadeOutDurationSeconds, preferredTimescale: 600) }
        set { fadeOutDurationSeconds = newValue.seconds }
    }
    
    var effects: [any AudioEffect] {
        get { effectWrappers.map { $0.effect } }
        set { effectWrappers = newValue.map { AudioEffectWrapper($0) } }
    }
    
    init(
        id: UUID = UUID(),
        linkedClipGroupId: UUID? = nil,
        sourceUrl: URL,
        sourceRange: CMTimeRange,
        timelineRange: CMTimeRange? = nil,
        isEnabled: Bool = true,
        volume: Float = 1.0,
        fadeInDuration: CMTime = .zero,
        fadeOutDuration: CMTime = .zero,
        effects: [any AudioEffect] = []
    ) {
        self.id = id
        self.linkedClipGroupId = linkedClipGroupId
        self.sourceUrl = sourceUrl
        self.sourceRange = sourceRange
        self.timelineRange = timelineRange ?? CMTimeRangeMake(start: .zero, duration: sourceRange.duration)
        self.isEnabled = isEnabled
        self.volume = volume
        self.fadeInDurationSeconds = fadeInDuration.seconds
        self.fadeOutDurationSeconds = fadeOutDuration.seconds
        self.effectWrappers = effects.map { AudioEffectWrapper($0) }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, linkedClipGroupId, sourceUrl, sourceRange, timelineRange, isEnabled
        case volume, fadeInDurationSeconds, fadeOutDurationSeconds
        case effectWrappers
    }
}

struct TextClip: ClipProtocol {
    let id: UUID
    var sourceRange: CMTimeRange
    var timelineRange: CMTimeRange
    var isEnabled: Bool
    
    var text: String
    var style: TextStyle
    var position: CGPoint
    var animations: [KeyframeAnimation]
    
    init(
        id: UUID = UUID(),
        timelineRange: CMTimeRange,
        isEnabled: Bool = true,
        text: String,
        style: TextStyle = .default,
        position: CGPoint = .zero,
        animations: [KeyframeAnimation] = []
    ) {
        self.id = id
        self.sourceRange = timelineRange
        self.timelineRange = timelineRange
        self.isEnabled = isEnabled
        self.text = text
        self.style = style
        self.position = position
        self.animations = animations
    }
}

struct OverlayClip: ClipProtocol {
    let id: UUID
    var sourceUrl: URL
    var sourceRange: CMTimeRange
    var timelineRange: CMTimeRange
    var isEnabled: Bool
    
    var transform: ClipTransform
    var blendMode: BlendMode
    var opacity: Float
    
    init(
        id: UUID = UUID(),
        sourceUrl: URL,
        sourceRange: CMTimeRange,
        timelineRange: CMTimeRange? = nil,
        isEnabled: Bool = true,
        transform: ClipTransform = .identity,
        blendMode: BlendMode = .normal,
        opacity: Float = 1.0
    ) {
        self.id = id
        self.sourceUrl = sourceUrl
        self.sourceRange = sourceRange
        self.timelineRange = timelineRange ?? CMTimeRangeMake(start: .zero, duration: sourceRange.duration)
        self.isEnabled = isEnabled
        self.transform = transform
        self.blendMode = blendMode
        self.opacity = opacity
    }
}
