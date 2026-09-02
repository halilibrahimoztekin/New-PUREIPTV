import ComposableArchitecture
#if os(iOS)
    import UIKit
#endif

@DependencyClient
public struct HapticClient {
    public var selection: @Sendable () async -> Void
    public var impact: @Sendable (_ style: ImpactStyle) async -> Void
    public var notification: @Sendable (_ type: NotificationType) async -> Void

    public enum ImpactStyle: Sendable {
        case light, medium, heavy, rigid, soft
    }

    public enum NotificationType: Sendable {
        case success, warning, error
    }
}

extension HapticClient: DependencyKey {
    public static let liveValue: HapticClient = .init(
        selection: {
            #if os(iOS)
                await MainActor.run {
                    let generator = UISelectionFeedbackGenerator()
                    generator.prepare()
                    generator.selectionChanged()
                }
            #endif
        },
        impact: { style in
            #if os(iOS)
                await MainActor.run {
                    let uiStyle: UIImpactFeedbackGenerator.FeedbackStyle = switch style {
                    case .light: .light
                    case .medium: .medium
                    case .heavy: .heavy
                    case .rigid: .rigid
                    case .soft: .soft
                    }
                    let generator = UIImpactFeedbackGenerator(style: uiStyle)
                    generator.prepare()
                    generator.impactOccurred()
                }
            #endif
        },
        notification: { type in
            #if os(iOS)
                await MainActor.run {
                    let uiType: UINotificationFeedbackGenerator.FeedbackType = switch type {
                    case .success: .success
                    case .warning: .warning
                    case .error: .error
                    }
                    let generator = UINotificationFeedbackGenerator()
                    generator.prepare()
                    generator.notificationOccurred(uiType)
                }
            #endif
        }
    )

    public static let testValue = HapticClient()
}

public extension DependencyValues {
    var hapticClient: HapticClient {
        get { self[HapticClient.self] }
        set { self[HapticClient.self] = newValue }
    }
}
