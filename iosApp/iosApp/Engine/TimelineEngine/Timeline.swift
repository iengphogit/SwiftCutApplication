import Foundation
import CoreMedia
import CoreGraphics

struct TimelineSettings: Codable {
    var canvasSize: CGSize
    var frameRate: Int
    var backgroundColorHex: String
    
    init(canvasSize: CGSize, frameRate: Int, backgroundColor: CGColor) {
        self.canvasSize = canvasSize
        self.frameRate = frameRate
        self.backgroundColorHex = Self.cgColorToHex(backgroundColor) ?? "#000000"
    }
    
    var backgroundColor: CGColor {
        Self.hexToCGColor(backgroundColorHex) ?? CGColor(gray: 0, alpha: 1)
    }
    
    private static func cgColorToHex(_ color: CGColor) -> String? {
        guard let components = color.converted(to: CGColorSpaceCreateDeviceRGB(), intent: .defaultIntent, options: nil)?.components,
              components.count >= 3 else { return nil }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
    
    private static func hexToCGColor(_ hex: String) -> CGColor? {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb), hexSanitized.count == 6 else { return nil }
        return CGColor(
            red: CGFloat((rgb & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgb & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgb & 0x0000FF) / 255.0,
            alpha: 1.0
        )
    }
    
    static let `default` = TimelineSettings(
        canvasSize: CGSize(width: 1080, height: 1920),
        frameRate: 30,
        backgroundColor: CGColor(gray: 0, alpha: 1)
    )
}

struct Timeline: Identifiable, Codable {
    let id: UUID
    var name: String
    var createdAt: Date
    var modifiedAt: Date
    var settings: TimelineSettings
    var tracks: [Track]
    
    var duration: CMTime {
        let trackDurations = tracks.compactMap { track -> CMTime? in
            let clipEnds = track.clips.compactMap { $0.timelineRange.end }
            return clipEnds.max()
        }
        return trackDurations.max() ?? .zero
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        settings: TimelineSettings = .default,
        tracks: [Track] = []
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.settings = settings
        self.tracks = tracks
    }
    
    func track(for id: UUID) -> Track? {
        tracks.first { $0.id == id }
    }
    
    func clip(for id: UUID) -> (track: Track, clip: any ClipProtocol)? {
        for track in tracks {
            if let clip = track.clips.first(where: { $0.id == id }) {
                return (track, clip)
            }
        }
        return nil
    }
    
    mutating func updateModifiedAt() {
        modifiedAt = Date()
    }
}

extension Timeline {
    enum Scenario {
        case basic
        case advanced
    }
    
    static func create(scenario: Scenario, name: String = "Untitled Project") -> Timeline {
        switch scenario {
        case .basic:
            return createBasicTimeline(name: name)
        case .advanced:
            return createAdvancedTimeline(name: name)
        }
    }
    
    private static func createBasicTimeline(name: String) -> Timeline {
        Timeline(
            name: name,
            settings: TimelineSettings(
                canvasSize: CGSize(width: 1080, height: 1920),
                frameRate: 30,
                backgroundColor: CGColor(gray: 0, alpha: 1)
            ),
            tracks: [
                Track(type: .audio, layer: .audioMusic, name: "Audio"),
                Track(type: .video, layer: .videoMain, name: "Video"),
                Track(type: .text, layer: .textOverlay, name: "Text"),
            ]
        )
    }
    
    private static func createAdvancedTimeline(name: String) -> Timeline {
        Timeline(
            name: name,
            settings: TimelineSettings(
                canvasSize: CGSize(width: 1080, height: 1920),
                frameRate: 30,
                backgroundColor: CGColor(gray: 0, alpha: 1)
            ),
            tracks: [
                Track(type: .audio, layer: .audioMusic, name: "Music"),
                Track(type: .audio, layer: .audioSfx, name: "Sound Effects"),
                Track(type: .audio, layer: .audioVoiceover, name: "Voiceover"),
                Track(type: .video, layer: .videoMain, name: "Main Video"),
                Track(type: .overlay, layer: .videoOverlay, name: "Overlays"),
                Track(type: .text, layer: .textOverlay, name: "Text"),
                Track(type: .effect, layer: .effectGlobal, name: "Effects"),
            ]
        )
    }
}
