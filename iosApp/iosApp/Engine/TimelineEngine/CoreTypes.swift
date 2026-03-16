import Foundation
import CoreMedia
import CoreGraphics

extension CMTime: @retroactive Comparable {
    public static func < (lhs: CMTime, rhs: CMTime) -> Bool {
        CMTimeCompare(lhs, rhs) < 0
    }
}

extension CMTime {
    static func + (lhs: CMTime, rhs: CMTime) -> CMTime {
        CMTimeAdd(lhs, rhs)
    }
    
    static func - (lhs: CMTime, rhs: CMTime) -> CMTime {
        CMTimeSubtract(lhs, rhs)
    }
    
    static func * (lhs: CMTime, rhs: Int32) -> CMTime {
        CMTimeMultiply(lhs, multiplier: rhs)
    }
    
    static func / (lhs: CMTime, rhs: Int32) -> CMTime {
        CMTimeMultiplyByRatio(lhs, multiplier: 1, divisor: rhs)
    }
    
    var isValid: Bool {
        CMTIME_IS_VALID(self)
    }
    
    var isPositive: Bool {
        isValid && seconds >= 0
    }
    
    var isZero: Bool {
        CMTimeCompare(self, .zero) == 0
    }
    
    static func seconds(_ seconds: Double, timescale: Int32 = 600) -> CMTime {
        CMTime(seconds: seconds, preferredTimescale: timescale)
    }
}

extension CMTimeRange {
    var duration: CMTime {
        CMTimeSubtract(end, start)
    }
    
    var isValid: Bool {
        CMTIMERANGE_IS_VALID(self)
    }
    
    var isEmpty: Bool {
        CMTIMERANGE_IS_EMPTY(self)
    }
    
    func containsTime(_ time: CMTime) -> Bool {
        CMTimeRangeContainsTime(self, time: time)
    }
    
    func intersection(_ other: CMTimeRange) -> CMTimeRange {
        CMTimeRangeGetIntersection(self, otherRange: other)
    }
    
    static func from(start: CMTime, duration: CMTime) -> CMTimeRange {
        CMTimeRangeMake(start: start, duration: duration)
    }
}

enum TrackType: String, Codable, CaseIterable {
    case video
    case audio
    case text
    case overlay
    case effect
}

enum TrackLayer: Int, Codable, Comparable {
    case background = 1
    case audioMusic = 10
    case audioSfx = 20
    case audioVoiceover = 30
    case videoMain = 40
    case videoOverlay = 50
    case textOverlay = 60
    case effectGlobal = 70
    
    static func < (lhs: TrackLayer, rhs: TrackLayer) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum BlendMode: String, Codable, CaseIterable {
    case normal
    case multiply
    case screen
    case overlay
    case darken
    case lighten
    case colorDodge
    case colorBurn
    case softLight
    case hardLight
    case difference
    case exclusion
}

enum EasingType: String, Codable {
    case linear
    case easeIn
    case easeOut
    case easeInOut
    case custom
}
