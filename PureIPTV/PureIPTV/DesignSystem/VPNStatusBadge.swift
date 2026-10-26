import SwiftUI

// MARK: - VPN Status Badge View (Madde #93)

public struct VPNStatusBadge: View {
    @ObservedObject private var vpnMonitor = VPNMonitor.shared
    public var compact: Bool

    public init(compact: Bool = false) {
        self.compact = compact
    }

    public var body: some View {
        let hasEvidence = vpnMonitor.hasVPNLikeInterfaceEvidence
        HStack(spacing: 5) {
            Image(systemName: hasEvidence ? "lock.shield.fill" : "shield")
                .font(.system(size: compact ? 10 : 12, weight: .bold))
                .foregroundStyle(hasEvidence ? Color.orange : Color.white.opacity(0.5))

            if !compact {
                Text(hasEvidence ? "VPN ARAYÜZÜ OLASI" : "VPN ARAYÜZÜ SAPTANMADI")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(hasEvidence ? Color.orange : Color.white.opacity(0.6))
            } else {
                Text("VPN")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .foregroundStyle(hasEvidence ? Color.orange : Color.white.opacity(0.5))
            }

            Circle()
                .fill(hasEvidence ? Color.orange : Color.gray.opacity(0.4))
                .frame(width: 5, height: 5)
                .shadow(color: hasEvidence ? Color.orange.opacity(0.65) : .clear, radius: 3)
        }
        .padding(.horizontal, compact ? 7 : 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(hasEvidence ? Color.orange.opacity(0.12) : Color.white.opacity(0.06))
                .overlay(
                    Capsule()
                        .stroke(hasEvidence ? Color.orange.opacity(0.35) : Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(hasEvidence ? "VPN benzeri arayüz olabilir" : "VPN benzeri arayüz saptanmadı")
        .accessibilityHint("Bu ağ arayüzü sinyali yayın trafiğinin VPN üzerinden gittiğini doğrulamaz.")
    }
}
