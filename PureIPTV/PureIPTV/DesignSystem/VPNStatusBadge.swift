import SwiftUI

// MARK: - VPN Status Badge View (Madde #93)

public struct VPNStatusBadge: View {
    @ObservedObject private var vpnMonitor = VPNMonitor.shared
    public var compact: Bool

    public init(compact: Bool = false) {
        self.compact = compact
    }

    public var body: some View {
        HStack(spacing: 5) {
            Image(systemName: vpnMonitor.isConnected ? "lock.shield.fill" : "shield")
                .font(.system(size: compact ? 10 : 12, weight: .bold))
                .foregroundStyle(vpnMonitor.isConnected ? Color.green : Color.white.opacity(0.5))

            if !compact {
                Text(vpnMonitor.isConnected ? "VPN AKTİF" : "VPN YOK")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(vpnMonitor.isConnected ? Color.green : Color.white.opacity(0.6))
            } else {
                Text("VPN")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .foregroundStyle(vpnMonitor.isConnected ? Color.green : Color.white.opacity(0.5))
            }

            Circle()
                .fill(vpnMonitor.isConnected ? Color.green : Color.gray.opacity(0.4))
                .frame(width: 5, height: 5)
                .shadow(color: vpnMonitor.isConnected ? Color.green.opacity(0.8) : .clear, radius: 3)
        }
        .padding(.horizontal, compact ? 7 : 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(vpnMonitor.isConnected ? Color.green.opacity(0.12) : Color.white.opacity(0.06))
                .overlay(
                    Capsule()
                        .stroke(vpnMonitor.isConnected ? Color.green.opacity(0.35) : Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}
