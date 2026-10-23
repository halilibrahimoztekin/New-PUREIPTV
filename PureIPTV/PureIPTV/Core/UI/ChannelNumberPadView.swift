import SwiftUI

public struct ChannelNumberPadView: View {
    public let channels: [MediaModels.Item]
    public let onSelectChannel: (MediaModels.Item) -> Void
    public let onDismiss: () -> Void

    @State private var dialedDigits: String = ""
    @State private var matchedChannel: MediaModels.Item?
    @State private var autoJumpCountdown: Int = 3
    @State private var timerTask: Task<Void, Never>?

    public init(
        channels: [MediaModels.Item],
        onSelectChannel: @escaping (MediaModels.Item) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.channels = channels
        self.onSelectChannel = onSelectChannel
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 20) {
            // Header: Dialed Digits & Matched Channel
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "number")
                        .font(.title2.bold())
                        .foregroundColor(.accentColor)
                    Text(dialedDigits.isEmpty ? "—" : dialedDigits)
                        .font(.system(size: 40, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                }

                if let matched = matchedChannel {
                    Text(matched.title)
                        .font(.headline.bold())
                        .foregroundColor(.green)
                        .lineLimit(1)
                } else if !dialedDigits.isEmpty {
                    Text("Kanal bulunamadı")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("Kanal numarasını tuşlayın")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 12)

            // Numpad 1 to 9
            VStack(spacing: 12) {
                ForEach(0 ..< 3) { row in
                    HStack(spacing: 14) {
                        ForEach(1 ... 3, id: \.self) { col in
                            let num = row * 3 + col
                            numpadButton(digit: "\(num)")
                        }
                    }
                }

                // Row 4: Clear, 0, Confirm
                HStack(spacing: 14) {
                    Button(action: clear) {
                        Image(systemName: "delete.left.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 68, height: 56)
                            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)

                    numpadButton(digit: "0")

                    Button(action: confirm) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 68, height: 56)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .disabled(matchedChannel == nil)
                }
            }

            // Dismiss Button
            Button("Kapat", action: onDismiss)
                .font(.footnote.bold())
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .onDisappear {
            timerTask?.cancel()
        }
    }

    private func numpadButton(digit: String) -> some View {
        Button(action: { appendDigit(digit) }) {
            Text(digit)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 68, height: 56)
                .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private func appendDigit(_ digit: String) {
        #if !os(tvOS)
            HapticManager.shared.trigger(.light)
        #endif
        if dialedDigits.count < 4 {
            dialedDigits.append(digit)
            resolveDialedChannel()
        }
    }

    private func clear() {
        #if !os(tvOS)
            HapticManager.shared.trigger(.medium)
        #endif
        if !dialedDigits.isEmpty {
            dialedDigits.removeLast()
            resolveDialedChannel()
        }
    }

    private func resolveDialedChannel() {
        guard let num = Int(dialedDigits), num > 0 else {
            matchedChannel = nil
            timerTask?.cancel()
            return
        }

        matchedChannel = ChannelNumberManager.shared.channel(forNumber: num, in: channels)
        if matchedChannel != nil {
            timerTask?.cancel()
            timerTask = Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if !Task.isCancelled {
                    confirm()
                }
            }
        }
    }

    private func confirm() {
        if let matched = matchedChannel {
            #if !os(tvOS)
                HapticManager.shared.trigger(.success)
            #endif
            onSelectChannel(matched)
            onDismiss()
        }
    }
}
