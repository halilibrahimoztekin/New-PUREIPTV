import Combine
import Foundation

@MainActor
public final class PowerEfficiencyManager: ObservableObject {
    public static let shared = PowerEfficiencyManager()

    @Published public private(set) var isLowPowerModeEnabled: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled

    private var cancellable: AnyCancellable?

    private init() {
        cancellable = NotificationCenter.default
            .publisher(for: NSNotification.Name.NSProcessInfoPowerStateDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
    }

    public var shouldThrottlePrebuffering: Bool {
        isLowPowerModeEnabled
    }

    public var shouldDisableMeshGradients: Bool {
        isLowPowerModeEnabled
    }
}
