import Foundation
import CoreMedia
import CoreGraphics

enum CompositionClipKind: String, Codable {
    case video
    case overlay
    case text
}

enum CompositionScaleMode: String, Codable {
    case fit
    case fill
    case stretch
}

struct CompositionTransform: Codable {
    var position: CGPoint
    var scale: CGSize
    var rotationDegrees: Double
    var opacity: Double
    var cropRect: CGRect?
    var scaleMode: CompositionScaleMode

    static let identity = CompositionTransform(
        position: .zero,
        scale: CGSize(width: 1, height: 1),
        rotationDegrees: 0,
        opacity: 1,
        cropRect: nil,
        scaleMode: .fit
    )
}

struct VisualClipSnapshot: Identifiable, Codable {
    let id: UUID
    let trackId: UUID
    let trackLayer: TrackLayer
    let timelineRange: CMTimeRange
    let sourceTimeSeconds: Double
    let playbackRate: Double
    let sourceURL: URL?
    let kind: CompositionClipKind
    let transform: CompositionTransform
    let text: String?
    let textStyle: TextStyle?
}

struct AudioClipSnapshot: Identifiable, Codable {
    let id: UUID
    let trackId: UUID
    let timelineRange: CMTimeRange
    let sourceStartSeconds: Double
    let sourceTimeSeconds: Double
    let sourceURL: URL
    let volume: Float
    let trackVolume: Float
    let effectiveVolume: Float
    let isMuted: Bool
    let isTrackSolo: Bool
}

struct CompositionFrame: Codable {
    let timelineTimeSeconds: Double
    let outputSize: CGSize
    let frameRate: Int
    let visualClips: [VisualClipSnapshot]
    let audioClips: [AudioClipSnapshot]
}
