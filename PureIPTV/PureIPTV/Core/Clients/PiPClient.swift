import AVFoundation
import AVKit
import ComposableArchitecture
import Foundation

// MARK: - Background Playback Mode

public enum BackgroundPlaybackMode: String, CaseIterable, Codable, Sendable, Equatable, Identifiable {
    case pip
    case audioOnly
    case disabled

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .pip:
            "Resim İçinde Resim (PiP)"
        case .audioOnly:
            "Yalnızca Ses (Arka Plan)"
        case .disabled:
            "Kapalı (Durdur)"
        }
    }

    public var icon: String {
        switch self {
        case .pip:
            "pip.enter"
        case .audioOnly:
            "waveform"
        case .disabled:
            "slash.circle"
        }
    }

    public var descriptionText: String {
        switch self {
        case .pip:
            "Uygulamadan çıkıldığında veya ana menüye dönüldüğünde video PiP penceresinde akmaya devam eder."
        case .audioOnly:
            "Ekran kilitlendiğinde veya arka plana geçildiğinde ses kesintisiz çalmaya devam eder."
        case .disabled:
            "Uygulama arka plana geçtiğinde video ve ses otomatik durdurulur."
        }
    }
}

// MARK: - PiPClient

public struct PiPClient: Sendable {
    public var isPiPSupported: @Sendable () -> Bool = { false }
    public var isAutoPiPEnabled: @Sendable () -> Bool = { true }
    public var setAutoPiPEnabled: @Sendable (Bool) -> Void = { _ in }
    public var backgroundPlaybackMode: @Sendable () -> BackgroundPlaybackMode = { .pip }
    public var setBackgroundPlaybackMode: @Sendable (BackgroundPlaybackMode) -> Void = { _ in }
    public var configureAudioSession: @Sendable (Bool) async throws -> Void = { _ in }

    public nonisolated init(
        isPiPSupported: @escaping @Sendable () -> Bool = { false },
        isAutoPiPEnabled: @escaping @Sendable () -> Bool = { true },
        setAutoPiPEnabled: @escaping @Sendable (Bool) -> Void = { _ in },
        backgroundPlaybackMode: @escaping @Sendable () -> BackgroundPlaybackMode = { .pip },
        setBackgroundPlaybackMode: @escaping @Sendable (BackgroundPlaybackMode) -> Void = { _ in },
        configureAudioSession: @escaping @Sendable (Bool) async throws -> Void = { _ in }
    ) {
        self.isPiPSupported = isPiPSupported
        self.isAutoPiPEnabled = isAutoPiPEnabled
        self.setAutoPiPEnabled = setAutoPiPEnabled
        self.backgroundPlaybackMode = backgroundPlaybackMode
        self.setBackgroundPlaybackMode = setBackgroundPlaybackMode
        self.configureAudioSession = configureAudioSession
    }
}

// MARK: - DependencyKey & Live Value

extension PiPClient: DependencyKey {
    public static let liveValue: PiPClient = {
        let defaults = UserDefaults.standard
        let autoPiPKey = "com.pureiptv.autoPiPEnabled"
        let bgPlaybackKey = "com.pureiptv.backgroundPlaybackMode"

        return PiPClient(
            isPiPSupported: {
                #if os(iOS) || os(tvOS)
                    return AVPictureInPictureController.isPictureInPictureSupported()
                #else
                    return false
                #endif
            },
            isAutoPiPEnabled: {
                if defaults.object(forKey: autoPiPKey) == nil {
                    return true
                }
                return defaults.bool(forKey: autoPiPKey)
            },
            setAutoPiPEnabled: { enabled in
                defaults.set(enabled, forKey: autoPiPKey)
            },
            backgroundPlaybackMode: {
                guard let raw = defaults.string(forKey: bgPlaybackKey),
                      let mode = BackgroundPlaybackMode(rawValue: raw)
                else {
                    return .pip
                }
                return mode
            },
            setBackgroundPlaybackMode: { mode in
                defaults.set(mode.rawValue, forKey: bgPlaybackKey)
            },
            configureAudioSession: { active in
                #if os(iOS) || os(tvOS)
                    try await PlaybackAudioSession.setActive(active)
                #endif
            }
        )
    }()

    public static let testValue: PiPClient = .init(
        isPiPSupported: { true },
        isAutoPiPEnabled: { true },
        setAutoPiPEnabled: { _ in },
        backgroundPlaybackMode: { .pip },
        setBackgroundPlaybackMode: { _ in },
        configureAudioSession: { _ in }
    )
}

public extension DependencyValues {
    var pipClient: PiPClient {
        get { self[PiPClient.self] }
        set { self[PiPClient.self] = newValue }
    }
}
