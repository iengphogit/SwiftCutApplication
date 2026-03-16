import Foundation
import CoreMedia
import CoreGraphics

struct KeyframeAnimation: Identifiable, Codable {
    let id: UUID
    var property: AnimatableProperty
    var keyframes: [Keyframe]
    
    init(id: UUID = UUID(), property: AnimatableProperty, keyframes: [Keyframe]) {
        self.id = id
        self.property = property
        self.keyframes = keyframes
    }
}

enum AnimatableProperty: String, Codable {
    case position
    case scale
    case rotation
    case opacity
    case volume
}

struct Keyframe: Codable {
    let timeSeconds: Double
    let value: AnimationValue
    let easing: EasingType
    
    var time: CMTime {
        CMTime(seconds: timeSeconds, preferredTimescale: 600)
    }
    
    init(time: CMTime, value: AnimationValue, easing: EasingType = .linear) {
        self.timeSeconds = time.seconds
        self.value = value
        self.easing = easing
    }
}

enum AnimationValue: Codable {
    case point(CGPoint)
    case size(CGSize)
    case float(CGFloat)
    case double(Double)
    
    var pointValue: CGPoint? {
        if case .point(let p) = self { return p }
        return nil
    }
    
    var sizeValue: CGSize? {
        if case .size(let s) = self { return s }
        return nil
    }
    
    var floatValue: CGFloat? {
        if case .float(let f) = self { return f }
        return nil
    }
    
    var doubleValue: Double? {
        if case .double(let d) = self { return d }
        return nil
    }
}
