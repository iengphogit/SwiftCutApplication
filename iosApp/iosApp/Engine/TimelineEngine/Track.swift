import Foundation
import CoreMedia

struct Track: Identifiable, Codable {
    var id: UUID
    var type: TrackType
    let layer: TrackLayer
    var name: String
    var isMuted: Bool
    var volume: Float
    var isSolo: Bool
    var isLocked: Bool
    var clips: [any ClipProtocol]
    
    var duration: CMTime {
        let clipEnds = clips.compactMap { $0.timelineRange.end }
        return clipEnds.max() ?? .zero
    }
    
    init(
        id: UUID = UUID(),
        type: TrackType,
        layer: TrackLayer,
        name: String,
        isMuted: Bool = false,
        volume: Float = 1.0,
        isSolo: Bool = false,
        isLocked: Bool = false,
        clips: [any ClipProtocol] = []
    ) {
        self.id = id
        self.type = type
        self.layer = layer
        self.name = name
        self.isMuted = isMuted
        self.volume = volume
        self.isSolo = isSolo
        self.isLocked = isLocked
        self.clips = clips
    }
    
    func clip(for id: UUID) -> (any ClipProtocol)? {
        clips.first { $0.id == id }
    }
    
    func clipIndex(for id: UUID) -> Int? {
        clips.firstIndex { $0.id == id }
    }
    
    func clips(at time: CMTime) -> [any ClipProtocol] {
        clips.filter { $0.timelineRange.containsTime(time) }
    }
    
    func clips(in range: CMTimeRange) -> [any ClipProtocol] {
        clips.filter { clip in
            let intersection = clip.timelineRange.intersection(range)
            return !intersection.isEmpty
        }
    }

    func supports(clip: any ClipProtocol) -> Bool {
        switch type {
        case .video:
            return clip is VideoClip
        case .audio:
            return clip is AudioClip
        case .text:
            return clip is TextClip
        case .overlay:
            return clip is OverlayClip
        case .effect:
            return false
        }
    }
}

extension Track {
    enum CodingKeys: String, CodingKey {
        case id, type, layer, name, isMuted, volume, isSolo, isLocked
        case clipData
    }
    
    enum ClipType: String, Codable {
        case video, audio, text, overlay
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(TrackType.self, forKey: .type)
        layer = try container.decode(TrackLayer.self, forKey: .layer)
        name = try container.decode(String.self, forKey: .name)
        isMuted = try container.decode(Bool.self, forKey: .isMuted)
        volume = try container.decodeIfPresent(Float.self, forKey: .volume) ?? 1.0
        isSolo = try container.decodeIfPresent(Bool.self, forKey: .isSolo) ?? false
        isLocked = try container.decode(Bool.self, forKey: .isLocked)
        
        let clipData = try container.decode([ClipWrapper].self, forKey: .clipData)
        clips = clipData.map { $0.clip }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(layer, forKey: .layer)
        try container.encode(name, forKey: .name)
        try container.encode(isMuted, forKey: .isMuted)
        try container.encode(volume, forKey: .volume)
        try container.encode(isSolo, forKey: .isSolo)
        try container.encode(isLocked, forKey: .isLocked)
        
        let clipData = clips.map { ClipWrapper($0) }
        try container.encode(clipData, forKey: .clipData)
    }
}

private struct ClipWrapper: Codable {
    let type: Track.ClipType
    let clip: any ClipProtocol
    
    init(_ clip: any ClipProtocol) {
        if let videoClip = clip as? VideoClip {
            self.type = .video
            self.clip = videoClip
        } else if let audioClip = clip as? AudioClip {
            self.type = .audio
            self.clip = audioClip
        } else if let textClip = clip as? TextClip {
            self.type = .text
            self.clip = textClip
        } else if let overlayClip = clip as? OverlayClip {
            self.type = .overlay
            self.clip = overlayClip
        } else {
            fatalError("Unknown clip type")
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case type, data
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(Track.ClipType.self, forKey: .type)
        
        switch type {
        case .video:
            clip = try container.decode(VideoClip.self, forKey: .data)
        case .audio:
            clip = try container.decode(AudioClip.self, forKey: .data)
        case .text:
            clip = try container.decode(TextClip.self, forKey: .data)
        case .overlay:
            clip = try container.decode(OverlayClip.self, forKey: .data)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        
        switch type {
        case .video:
            try container.encode(clip as! VideoClip, forKey: .data)
        case .audio:
            try container.encode(clip as! AudioClip, forKey: .data)
        case .text:
            try container.encode(clip as! TextClip, forKey: .data)
        case .overlay:
            try container.encode(clip as! OverlayClip, forKey: .data)
        }
    }
}
