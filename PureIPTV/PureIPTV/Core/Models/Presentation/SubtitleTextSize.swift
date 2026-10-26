import Foundation

public enum SubtitleTextSize: Int, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case small = 80
    case standard = 100
    case large = 125
    case extraLarge = 150

    public var id: Int {
        rawValue
    }

    public var scale: Float {
        Float(rawValue) / 100
    }

    public var title: String {
        "\(rawValue)%"
    }
}
