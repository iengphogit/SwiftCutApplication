import Foundation

protocol AudioEffect: Identifiable, Codable {
    var id: UUID { get }
    var isEnabled: Bool { get set }
}

struct EqualizerEffect: AudioEffect {
    let id: UUID
    var isEnabled: Bool
    var bands: [EQBand]
    
    init(id: UUID = UUID(), isEnabled: Bool = true, bands: [EQBand] = []) {
        self.id = id
        self.isEnabled = isEnabled
        self.bands = bands
    }
}

struct EQBand: Codable {
    let frequency: Float
    var gain: Float
    
    init(frequency: Float, gain: Float = 0) {
        self.frequency = frequency
        self.gain = gain
    }
}

struct ReverbEffect: AudioEffect {
    let id: UUID
    var isEnabled: Bool
    var roomSize: Float
    var wetLevel: Float
    var dryLevel: Float
    
    init(id: UUID = UUID(), isEnabled: Bool = true, roomSize: Float = 0.5, wetLevel: Float = 0.3, dryLevel: Float = 0.7) {
        self.id = id
        self.isEnabled = isEnabled
        self.roomSize = roomSize
        self.wetLevel = wetLevel
        self.dryLevel = dryLevel
    }
}

struct NoiseReductionEffect: AudioEffect {
    let id: UUID
    var isEnabled: Bool
    var strength: Float
    
    init(id: UUID = UUID(), isEnabled: Bool = true, strength: Float = 0.5) {
        self.id = id
        self.isEnabled = isEnabled
        self.strength = strength
    }
}

struct AudioEffectWrapper: Codable {
    let type: AudioEffectType
    let effect: any AudioEffect
    
    init(_ effect: any AudioEffect) {
        if let eq = effect as? EqualizerEffect {
            self.type = .equalizer
            self.effect = eq
        } else if let reverb = effect as? ReverbEffect {
            self.type = .reverb
            self.effect = reverb
        } else if let noise = effect as? NoiseReductionEffect {
            self.type = .noiseReduction
            self.effect = noise
        } else {
            fatalError("Unknown audio effect type")
        }
    }
    
    enum AudioEffectType: String, Codable {
        case equalizer
        case reverb
        case noiseReduction
    }
    
    enum CodingKeys: String, CodingKey {
        case type, data
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(AudioEffectType.self, forKey: .type)
        
        switch type {
        case .equalizer:
            effect = try container.decode(EqualizerEffect.self, forKey: .data)
        case .reverb:
            effect = try container.decode(ReverbEffect.self, forKey: .data)
        case .noiseReduction:
            effect = try container.decode(NoiseReductionEffect.self, forKey: .data)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        
        switch type {
        case .equalizer:
            try container.encode(effect as! EqualizerEffect, forKey: .data)
        case .reverb:
            try container.encode(effect as! ReverbEffect, forKey: .data)
        case .noiseReduction:
            try container.encode(effect as! NoiseReductionEffect, forKey: .data)
        }
    }
}
