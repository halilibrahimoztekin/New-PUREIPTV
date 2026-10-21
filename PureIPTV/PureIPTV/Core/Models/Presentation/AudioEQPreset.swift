import Foundation
import SwiftUI

// MARK: - Live Stream Audio Equalizer Presets (Madde #14)

public enum AudioEQPreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case flat
    case dialogueEnhancer = "dialogue_enhancer"
    case stadium
    case nightMode = "night_mode"
    case bassBoost = "bass_boost"
    case acoustic

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .flat:
            "Doğal (Flat)"
        case .dialogueEnhancer:
            "Diyalog Netleştirici"
        case .stadium:
            "Stadyum & Spor"
        case .nightMode:
            "Gece Modu"
        case .bassBoost:
            "Bas Güçlendirici"
        case .acoustic:
            "Akustik & Berrak"
        }
    }

    public var subtitle: String {
        switch self {
        case .flat:
            "Filtresiz orijinal stüdyo sesi"
        case .dialogueEnhancer:
            "İnsan seslerini öne çıkarır, arka plan uğultusunu bastırır"
        case .stadium:
            "Tribün ambiyansını derinleştirir, spiker sesini dengeler"
        case .nightMode:
            "Patlama ve tizleri kısar, fısıltıları anlaşılır kılar"
        case .bassBoost:
            "Aksiyon ve müzik için güçlü bas vuruşları"
        case .acoustic:
            "Konser, müzik ve belgesel için berrak ses sahnesi"
        }
    }

    public var icon: String {
        switch self {
        case .flat:
            "waveform"
        case .dialogueEnhancer:
            "person.wave.2.fill"
        case .stadium:
            "sportscourt.fill"
        case .nightMode:
            "moon.stars.fill"
        case .bassBoost:
            "speaker.wave.3.fill"
        case .acoustic:
            "music.note.list"
        }
    }

    public var accentColor: Color {
        switch self {
        case .flat:
            Color(hex: "#0A84FF")
        case .dialogueEnhancer:
            Color(hex: "#30D158")
        case .stadium:
            Color(hex: "#FF9F0A")
        case .nightMode:
            Color(hex: "#BF5AF2")
        case .bassBoost:
            Color(hex: "#FF375F")
        case .acoustic:
            Color(hex: "#64D2FF")
        }
    }

    /// 10 standard ISO frequency band labels (Hz / kHz)
    public static let bandFrequencies: [String] = [
        "60Hz", "170Hz", "310Hz", "600Hz", "1kHz", "3kHz", "6kHz", "12kHz", "14kHz", "16kHz",
    ]

    /// Per-band gain in decibels (-20.0 dB ... +20.0 dB) for each of the 10 equalizer bands
    public var bandGains: [Float] {
        switch self {
        case .flat:
            [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
        case .dialogueEnhancer:
            [-4.0, -3.0, -1.5, +2.0, +5.0, +5.5, +3.5, +1.0, -1.0, -2.0]
        case .stadium:
            [+2.5, +1.5, 0.0, -1.5, +3.5, +4.0, +2.5, +3.0, +2.0, +1.0]
        case .nightMode:
            [-7.0, -5.0, -2.5, +1.5, +3.5, +3.0, +1.0, -3.0, -5.0, -7.0]
        case .bassBoost:
            [+6.5, +5.0, +3.0, +1.0, 0.0, 0.0, 0.0, +1.0, +2.0, +2.0]
        case .acoustic:
            [+1.5, +1.0, 0.0, +1.5, +2.5, +3.5, +4.0, +3.5, +2.0, +1.5]
        }
    }

    /// Preamp amplification (dB)
    public var preamp: Float {
        switch self {
        case .flat:
            0.0
        case .dialogueEnhancer:
            1.5
        case .stadium:
            1.0
        case .nightMode:
            -1.0
        case .bassBoost:
            1.0
        case .acoustic:
            0.5
        }
    }
}
