import Foundation
import CoreGraphics
import CoreImage

struct ClipTransform: Codable {
    var position: CGPoint
    var scale: CGSize
    var rotation: CGFloat
    var cropRect: CGRect?
    
    static let identity = ClipTransform(
        position: .zero,
        scale: CGSize(width: 1, height: 1),
        rotation: 0,
        cropRect: nil
    )
}

struct ColorAdjustments: Codable {
    var brightness: Float
    var contrast: Float
    var saturation: Float
    var warmth: Float
    var tint: Float
    var exposure: Float
    var highlights: Float
    var shadows: Float
    var sharpness: Float
    var vignette: Float
    
    static let `default` = ColorAdjustments(
        brightness: 0,
        contrast: 0,
        saturation: 0,
        warmth: 0,
        tint: 0,
        exposure: 0,
        highlights: 0,
        shadows: 0,
        sharpness: 0,
        vignette: 0
    )
}

struct Filter: Identifiable, Codable {
    let id: UUID
    var name: String
    var intensity: Float
    var lutUrl: URL?
    
    init(id: UUID = UUID(), name: String, intensity: Float = 1.0, lutUrl: URL? = nil) {
        self.id = id
        self.name = name
        self.intensity = intensity
        self.lutUrl = lutUrl
    }
}

enum PresetFilter: String, CaseIterable, Codable {
    case none
    case vivid
    case warm
    case cool
    case vintage
    case noir
    case fade
    case cinematic
    case retro
    case fresh
    
    var displayName: String { rawValue.capitalized }
}
