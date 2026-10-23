import ComposableArchitecture
import SwiftUI

// MARK: - Direct Channel Number Dialing HUD View (Madde #11)

public struct DirectChannelDialHUDView: View {
    @Bindable var store: StoreOf<PlayerFeature>
    let onDismiss: () -> Void

    @FocusState private var focusedKey: String?

    public init(store: StoreOf<PlayerFeature>, onDismiss: @escaping () -> Void) {
        self.store = store
        self.onDismiss = onDismiss
    }

    private let keyRows: [[KeyPadItem]] = [
        [.digit("1"), .digit("2"), .digit("3")],
        [.digit("4"), .digit("5"), .digit("6")],
        [.digit("7"), .digit("8"), .digit("9")],
        [.delete, .digit("0"), .submit],
    ]

    private enum KeyPadItem: Hashable {
        case digit(String)
        case delete
        case submit

        var id: String {
            switch self {
            case let .digit(d): d
            case .delete: "delete"
            case .submit: "submit"
            }
        }
    }

    public var body: some View {
        ZStack {
            // Tap-outside overlay to dismiss
            Color.black.opacity(0.65)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    onDismiss()
                }

            // Dial Pad Modal Card
            VStack(spacing: 20) {
                // Header Bar
                headerView

                // Digital Number Display
                numberDisplayView

                // Instant Channel Match Preview Cards
                if !store.matchedDialedChannels.isEmpty {
                    matchingChannelsPreviewStrip
                }

                // 10-Key Glass Keypad
                keypadGridView
            }
            #if os(tvOS)
            .padding(36)
            .frame(width: 560)
            .focusSection()
            #else
            .padding(24)
            .frame(width: min(380, UIScreen.main.bounds.width * 0.92))
            #endif
            .background(
                ZStack {
                    #if os(tvOS)
                        Color.black.opacity(0.92)
                    #else
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.ultraThinMaterial)
                        Color.black.opacity(0.65)
                    #endif
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: "#0A84FF").opacity(0.6),
                                Color.white.opacity(0.12),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: Color(hex: "#0A84FF").opacity(0.3), radius: 24, x: 0, y: 10)
            .shadow(color: Color.black.opacity(0.8), radius: 20, x: 0, y: 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.scale(scale: 0.92).combined(with: .opacity))
        .onAppear {
            #if os(tvOS)
                focusedKey = "5" // Center focus for Siri Remote
            #endif
        }
        #if os(tvOS)
        .onExitCommand {
            onDismiss()
        }
        #endif
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "numbers.rectangle.fill")
            #if os(tvOS)
                .font(.system(size: 26, weight: .bold))
            #else
                .font(.title3.weight(.bold))
            #endif
                .foregroundStyle(Color(hex: "#0A84FF"))

            VStack(alignment: .leading, spacing: 2) {
                Text(AppStrings.LiveTV.channelDialerTitle)
                #if os(tvOS)
                    .font(.system(size: 22, weight: .bold))
                #else
                    .font(.headline.weight(.bold))
                #endif
                    .foregroundStyle(.white)

                Text(AppStrings.LiveTV.channelDialerHint)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                #if os(tvOS)
                    .font(.system(size: 26))
                #else
                    .font(.title3)
                #endif
                    .foregroundStyle(.white.opacity(0.65))
            }
            #if os(tvOS)
            .buttonStyle(TVCircleButtonStyle())
            #else
            .buttonStyle(.plain)
            #endif
        }
    }

    // MARK: - Number Display View

    private var numberDisplayView: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color(hex: "#0A84FF").opacity(0.3), lineWidth: 1)
                    )

                HStack(spacing: 8) {
                    if store.dialedChannelNumber.isEmpty {
                        Text("_ _ _")
                            .font(.system(size: 38, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.25))
                    } else {
                        Text(store.dialedChannelNumber)
                            .font(.system(size: 40, weight: .black, design: .monospaced))
                            .foregroundStyle(Color(hex: "#0A84FF"))
                            .shadow(color: Color(hex: "#0A84FF").opacity(0.5), radius: 8, x: 0, y: 0)
                    }
                }
                .padding(.vertical, 14)
            }
            #if os(tvOS)
            .frame(height: 72)
            #else
            .frame(height: 60)
            #endif
        }
    }

    // MARK: - Matching Channels Preview Strip

    private var matchingChannelsPreviewStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.matchedDialedChannels, id: \.index) { match in
                    Button {
                        #if !os(tvOS)
                            HapticManager.shared.trigger(.light)
                        #endif
                        store.send(.selectChannel(match.item))
                        onDismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Text("#\(match.index)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(hex: "#0A84FF"))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color(hex: "#0A84FF").opacity(0.2), in: Capsule())

                            Text(match.item.title)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                    }
                    #if os(tvOS)
                    .buttonStyle(.card)
                    #else
                    .buttonStyle(.plain)
                    #endif
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - Keypad Grid View

    private var keypadGridView: some View {
        VStack(spacing: 12) {
            ForEach(keyRows, id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(row, id: \.id) { keyItem in
                        keypadButton(item: keyItem)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func keypadButton(item: KeyPadItem) -> some View {
        Button {
            #if !os(tvOS)
                HapticManager.shared.trigger(.light)
            #endif
            switch item {
            case let .digit(d):
                store.send(.appendDialedDigit(d))
            case .delete:
                store.send(.deleteDialedDigit)
            case .submit:
                store.send(.submitDialedChannel)
                onDismiss()
            }
        } label: {
            ZStack {
                switch item {
                case let .digit(d):
                    Text(d)
                    #if os(tvOS)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    #else
                        .font(.title2.weight(.bold))
                    #endif
                        .foregroundStyle(.white)

                case .delete:
                    Image(systemName: "delete.left.fill")
                    #if os(tvOS)
                        .font(.system(size: 22, weight: .bold))
                    #else
                        .font(.body.weight(.bold))
                    #endif
                        .foregroundStyle(Color(hex: "#FF453A"))

                case .submit:
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle.fill")
                        #if os(tvOS)
                            .font(.system(size: 20, weight: .bold))
                        #else
                            .font(.body.weight(.bold))
                        #endif
                    }
                    .foregroundStyle(Color(hex: "#30D158"))
                }
            }
            .frame(maxWidth: .infinity)
            #if os(tvOS)
                .frame(height: 60)
            #else
                .frame(height: 50)
            #endif
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(item == .submit ? 0.16 : 0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            item == .submit
                                ? Color(hex: "#30D158").opacity(0.4)
                                : Color.white.opacity(0.12),
                            lineWidth: 1
                        )
                )
        }
        #if os(tvOS)
        .buttonStyle(TVDialKeypadButtonStyle(isSubmit: item == .submit))
        .focused($focusedKey, equals: item.id)
        #else
        .buttonStyle(.plain)
        #endif
    }
}

// MARK: - tvOS Keypad Button Style

#if os(tvOS)
    private struct TVDialKeypadButtonStyle: ButtonStyle {
        let isSubmit: Bool

        func makeBody(configuration: Configuration) -> some View {
            TVDialKeypadBody(configuration: configuration, isSubmit: isSubmit)
        }

        private struct TVDialKeypadBody: View {
            let configuration: Configuration
            let isSubmit: Bool
            @Environment(\.isFocused) private var isFocused

            var body: some View {
                configuration.label
                    .scaleEffect(isFocused ? 1.12 : 1.0)
                    .brightness(isFocused ? 0.2 : 0.0)
                    .shadow(
                        color: isFocused
                            ? (isSubmit ? Color(hex: "#30D158").opacity(0.8) : Color(hex: "#0A84FF").opacity(0.8))
                            : .clear,
                        radius: isFocused ? 12 : 0,
                        x: 0,
                        y: 0
                    )
                    .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isFocused)
            }
        }
    }
#endif
