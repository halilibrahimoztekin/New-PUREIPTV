import Combine
import Foundation
import Network

// MARK: - VPN Monitor & Status Detector (Madde #93)

/// Real-time VPN connection status monitor.
/// Uses NWPathMonitor interface inspection and system network scoping to detect active VPN tunnels
/// (utun, ipsec, ppp, wireguard, openvpn) across both iOS and tvOS (tvOS 17+ VPN support).
@MainActor
public final class VPNMonitor: ObservableObject {
    public static let shared = VPNMonitor()

    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var activeInterfaceName: String? = nil

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.pureiptv.vpnmonitor", qos: .utility)

    private init() {
        startMonitoring()
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            let (isVPN, ifaceName) = Self.checkVPN(path: path)
            Task { @MainActor [weak self] in
                self?.isConnected = isVPN
                self?.activeInterfaceName = ifaceName
            }
        }
        monitor.start(queue: monitorQueue)
    }

    /// Evaluates whether an active VPN interface is handling network traffic.
    public nonisolated static func checkVPN(path: NWPath? = nil) -> (isVPN: Bool, interface: String?) {
        // 1. Check NWPath interface types
        if let path {
            for interface in path.availableInterfaces {
                let name = interface.name.lowercased()
                if interface.type == .other ||
                    name.hasPrefix("utun") ||
                    name.hasPrefix("tun") ||
                    name.hasPrefix("ppp") ||
                    name.hasPrefix("ipsec") ||
                    name.hasPrefix("tap") ||
                    name.contains("vpn")
                {
                    return (true, interface.name)
                }
            }
        }

        // 2. Fallback check via system proxy / scoped network dictionary
        if let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any],
           let scoped = settings["__SCOPED__"] as? [String: Any]
        {
            for key in scoped.keys {
                let lower = key.lowercased()
                if lower.hasPrefix("utun") ||
                    lower.hasPrefix("tun") ||
                    lower.hasPrefix("ppp") ||
                    lower.hasPrefix("ipsec") ||
                    lower.hasPrefix("tap") ||
                    lower.contains("vpn")
                {
                    return (true, key)
                }
            }
        }

        return (false, nil)
    }

    deinit {
        monitor.cancel()
    }
}
