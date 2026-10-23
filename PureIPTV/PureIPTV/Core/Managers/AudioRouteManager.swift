import AVFoundation
import Combine
import Foundation

public enum AudioRouteType: String, Sendable, Equatable {
    case speaker
    case airPlay
    case airPods
    case bluetooth
    case wired
    case unknown
}

public struct AudioRouteInfo: Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let type: AudioRouteType
    public let iconName: String
    public let isExternal: Bool

    public init(id: String, name: String, type: AudioRouteType, iconName: String, isExternal: Bool) {
        self.id = id
        self.name = name
        self.type = type
        self.iconName = iconName
        self.isExternal = isExternal
    }

    public static let defaultSpeaker = AudioRouteInfo(
        id: "built_in_speaker",
        name: "Hoparlör",
        type: .speaker,
        iconName: "speaker.wave.2.fill",
        isExternal: false
    )
}

@MainActor
public final class AudioRouteManager: ObservableObject {
    public static let shared = AudioRouteManager()

    @Published public private(set) var currentRoute: AudioRouteInfo = .defaultSpeaker

    private var cancellables = Set<AnyCancellable>()

    private init() {
        updateCurrentRoute()
        setupNotificationObserver()
    }

    public func updateCurrentRoute() {
        let session = AVAudioSession.sharedInstance()
        let outputs = session.currentRoute.outputs

        guard let primaryOutput = outputs.first else {
            currentRoute = .defaultSpeaker
            return
        }

        let portType = primaryOutput.portType
        let portName = primaryOutput.portName

        let routeInfo: AudioRouteInfo
        switch portType {
        case .airPlay:
            routeInfo = AudioRouteInfo(
                id: primaryOutput.uid,
                name: portName.isEmpty ? "AirPlay" : portName,
                type: .airPlay,
                iconName: "airplayaudio",
                isExternal: true
            )

        case .bluetoothA2DP, .bluetoothLE, .bluetoothHFP:
            let isAirPods = portName.localizedCaseInsensitiveContains("AirPods") || portName.localizedCaseInsensitiveContains("Beats")
            routeInfo = AudioRouteInfo(
                id: primaryOutput.uid,
                name: portName.isEmpty ? "Bluetooth" : portName,
                type: isAirPods ? .airPods : .bluetooth,
                iconName: isAirPods ? "airpodspro" : "headphones",
                isExternal: true
            )

        case .headphones, .headsetMic:
            routeInfo = AudioRouteInfo(
                id: primaryOutput.uid,
                name: portName.isEmpty ? "Kulaklık" : portName,
                type: .wired,
                iconName: "headphones",
                isExternal: true
            )

        case .builtInSpeaker, .builtInReceiver:
            routeInfo = .defaultSpeaker

        default:
            routeInfo = AudioRouteInfo(
                id: primaryOutput.uid,
                name: portName.isEmpty ? "Ses Çıkışı" : portName,
                type: .unknown,
                iconName: "speaker.wave.2.fill",
                isExternal: false
            )
        }

        if currentRoute != routeInfo {
            currentRoute = routeInfo
        }
    }

    private func setupNotificationObserver() {
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                updateCurrentRoute()
            }
            .store(in: &cancellables)
    }

    public func routeStream() -> AsyncStream<AudioRouteInfo> {
        AsyncStream { continuation in
            let cancellable = NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    guard let self else { return }
                    updateCurrentRoute()
                    continuation.yield(currentRoute)
                }

            // Yield initial value immediately
            continuation.yield(self.currentRoute)

            continuation.onTermination = { _ in
                cancellable.cancel()
            }
        }
    }
}
