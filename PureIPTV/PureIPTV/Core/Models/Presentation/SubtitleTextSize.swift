import Foundation

public nonisolated enum SubtitleTextSize: Int, CaseIterable, Codable, Equatable, Identifiable, Sendable {
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

public nonisolated enum ExternalSubtitleTextEncoding: String, CaseIterable, Codable, Equatable, Hashable, Identifiable, Sendable {
    case automatic
    case utf8
    case windows1252
    case windows1254
    case windows1251
    case utf16

    public static let userDefaultsKey = "com.pureiptv.externalSubtitleTextEncoding"
    public static let temporaryFilePrefix = "PureIPTV-ExternalSubtitle-"

    public var id: Self {
        self
    }

    public var title: String {
        switch self {
        case .automatic: AppStrings.Player.subtitleEncodingAutomatic
        case .utf8: "UTF-8"
        case .windows1252: "Windows-1252"
        case .windows1254: "Windows-1254"
        case .windows1251: "Windows-1251"
        case .utf16: "UTF-16"
        }
    }

    public var foundationEncoding: String.Encoding? {
        switch self {
        case .automatic: nil
        case .utf8: .utf8
        case .windows1252: .windowsCP1252
        case .windows1254: .windowsCP1254
        case .windows1251: .windowsCP1251
        case .utf16: .utf16
        }
    }

    public func decode(_ data: Data) -> String? {
        guard let foundationEncoding,
              let text = String(data: data, encoding: foundationEncoding)
        else { return nil }
        let invalidControls = CharacterSet.controlCharacters.subtracting(CharacterSet(charactersIn: "\r\n\t"))
        guard !text.unicodeScalars.contains(where: { invalidControls.contains($0) }) else { return nil }
        return text
    }

    public func supportsTextFileFormat(_ fileFormat: String?) -> Bool {
        guard let fileFormat else { return false }
        return ["srt", "vtt", "ass", "ssa", "smi", "sami"].contains(fileFormat.lowercased())
    }

    public func writeUTF8TemporaryFile(_ text: String, fileFormat: String) throws -> URL {
        guard supportsTextFileFormat(fileFormat) else { throw OpenSubtitlesClientError.subtitleEncodingFailed }
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(Self.temporaryFilePrefix + UUID().uuidString)
            .appendingPathExtension(fileFormat.lowercased())
        try text.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    public static func isOwnedTemporaryFile(_ url: URL) -> Bool {
        url.isFileURL
            && url.deletingLastPathComponent().standardizedFileURL == FileManager.default.temporaryDirectory.standardizedFileURL
            && url.lastPathComponent.hasPrefix(temporaryFilePrefix)
    }
}

public nonisolated enum SubtitleAppearanceProfile: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case standard
    case softGray
    case dimGray

    public static let userDefaultsKey = "com.pureiptv.subtitleAppearanceProfile"

    public var id: Self {
        self
    }

    public var title: String {
        switch self {
        case .standard: AppStrings.Settings.subtitleAppearanceStandard
        case .softGray: AppStrings.Settings.subtitleAppearanceSoftGray
        case .dimGray: AppStrings.Settings.subtitleAppearanceDimGray
        }
    }

    public var libVLCArguments: [String] {
        switch self {
        case .standard:
            []
        case .softGray:
            [
                "--freetype-color=\(0xD6D6D6)",
                "--freetype-opacity=230",
                "--freetype-outline-color=0",
                "--freetype-outline-opacity=255",
                "--freetype-outline-thickness=3",
            ]
        case .dimGray:
            [
                "--freetype-color=\(0xC0C0C0)",
                "--freetype-opacity=204",
                "--freetype-outline-color=0",
                "--freetype-outline-opacity=240",
                "--freetype-outline-thickness=3",
            ]
        }
    }

    public static var selectedForNextLaunch: Self {
        UserDefaults.standard.string(forKey: userDefaultsKey)
            .flatMap(Self.init(rawValue:)) ?? .standard
    }
}
