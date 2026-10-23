import Combine
import Foundation

public enum UserAgentPreset: String, CaseIterable, Identifiable, Sendable {
    case standard = "Varsayılan (PureIPTV)"
    case vlc = "VLC 3.0 (Tavsiye Edilen)"
    case tiviMate = "TiviMate 4.7"
    case appleCoreMedia = "AppleCoreMedia (tvOS Native)"
    case exoPlayer = "ExoPlayer (Android TV)"
    case custom = "Özel (Manuel Giriş)"

    public var id: String {
        rawValue
    }

    public nonisolated var userAgentString: String {
        switch self {
        case .standard:
            #if os(tvOS)
                return "PureIPTV/1.0 (AppleTV; tvOS 17.0)"
            #else
                return "PureIPTV/1.0 (iPhone; iOS 17.0)"
            #endif
        case .vlc:
            return "VLC/3.0.18 LibVLC/3.0.18"
        case .tiviMate:
            return "TiviMate/4.7.0 (Android TV)"
        case .appleCoreMedia:
            return "AppleCoreMedia/1.0.0.21J354 (Apple TV; U; CPU OS 17_0 like Mac OS X)"
        case .exoPlayer:
            return "ExoPlayerLib/2.18.7"
        case .custom:
            return ""
        }
    }
}

@MainActor
public final class UserAgentManager: ObservableObject {
    public static let shared = UserAgentManager()

    private let presetKey = "pureiptv_user_agent_preset"
    private let customStringKey = "pureiptv_user_agent_custom"

    @Published public var currentPreset: UserAgentPreset = .vlc {
        didSet {
            UserDefaults.standard.set(currentPreset.rawValue, forKey: presetKey)
        }
    }

    @Published public var customUserAgentString: String = "" {
        didSet {
            UserDefaults.standard.set(customUserAgentString, forKey: customStringKey)
        }
    }

    private init() {
        if let savedRaw = UserDefaults.standard.string(forKey: presetKey),
           let preset = UserAgentPreset(rawValue: savedRaw)
        {
            currentPreset = preset
        } else {
            currentPreset = .vlc
        }

        customUserAgentString = UserDefaults.standard.string(forKey: customStringKey) ?? ""
    }

    public nonisolated var resolvedUserAgent: String {
        Self.resolveUserAgent()
    }

    public nonisolated static func resolveUserAgent() -> String {
        let presetRaw = UserDefaults.standard.string(forKey: "pureiptv_user_agent_preset")
        let customString = UserDefaults.standard.string(forKey: "pureiptv_user_agent_custom") ?? ""
        if presetRaw == UserAgentPreset.custom.rawValue, !customString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return customString.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let preset = presetRaw.flatMap(UserAgentPreset.init) ?? .vlc
        return preset.userAgentString
    }

    public nonisolated func applyHeaders(to request: inout URLRequest, override: String? = nil) {
        Self.applyHeaders(to: &request, override: override)
    }

    public nonisolated static func applyHeaders(to request: inout URLRequest, override: String? = nil) {
        let value = override?.trimmingCharacters(in: .whitespacesAndNewlines)
        request.setValue(value?.isEmpty == false ? value : resolveUserAgent(), forHTTPHeaderField: "User-Agent")
    }
}
