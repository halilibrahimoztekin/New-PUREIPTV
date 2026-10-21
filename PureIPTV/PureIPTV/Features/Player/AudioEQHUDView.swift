import ComposableArchitecture
import SwiftUI

// MARK: - Live Stream Audio Equalizer Presets & Dialogue Enhancer HUD (Madde #14)

public struct AudioEQHUDView: View {
    @Bindable var store: StoreOf<PlayerFeature>
    let onClose: () -> Void

    @FocusState private var focusedPreset: AudioEQPreset?
    @FocusState private var isCloseFocused: Bool
    @State private var idleTimer: DispatchWorkItem?

    public init(store: StoreOf<PlayerFeature>, onClose: @escaping () -> Void) {
        self.store = store
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 20) {
            // Header Bar
            headerBar

            // 10-Band Dynamic EQ Visualizer Curve
            eqFrequencyVisualizer

            // Presets Grid
            presetsGrid

            // Channel Preference Footer
            footerInfoBar
        }
        .padding(24)
        .frame(maxWidth: containerMaxWidth)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(hex: "#0C0C10").opacity(0.94))
                .background(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    store.audioEQPreset.accentColor.opacity(0.6),
                                    Color.white.opacity(0.12),
                                    Color.white.opacity(0.04),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
                .shadow(color: store.audioEQPreset.accentColor.opacity(0.25), radius: 30, x: 0, y: 15)
                .shadow(color: .black.opacity(0.6), radius: 40, x: 0, y: 20)
        }
        #if os(tvOS)
        .onExitCommand {
            cancelIdleTimer()
            onClose()
        }
        #endif
        .onAppear {
            resetIdleTimer()
            #if os(tvOS)
                focusedPreset = store.audioEQPreset
            #endif
        }
        .onDisappear {
            cancelIdleTimer()
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(store.audioEQPreset.accentColor.opacity(0.18))
                    .frame(width: 42, height: 42)

                Image(systemName: "waveform.badge.magnifyingglass")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(store.audioEQPreset.accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("Ses Ekolayzer & Diyalog")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("PRO")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(store.audioEQPreset.accentColor, in: Capsule())
                }

                Text("İçeriğe özel sinematik ses optimizasyonu")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            Button {
                cancelIdleTimer()
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.75))
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
            #if os(tvOS)
                .focused($isCloseFocused)
            #endif
        }
    }

    // MARK: - 10-Band EQ Frequency Visualizer

    private var eqFrequencyVisualizer: some View {
        VStack(spacing: 10) {
            // Visualizer Canvas
            HStack(alignment: .bottom, spacing: visualizerBarSpacing) {
                ForEach(0 ..< AudioEQPreset.bandFrequencies.count, id: \.self) { index in
                    let label = AudioEQPreset.bandFrequencies[index]
                    let gain = store.audioEQPreset.bandGains[index]

                    VStack(spacing: 4) {
                        // dB readout
                        Text(String(format: "%+.0f", gain))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(gain == 0 ? .white.opacity(0.4) : store.audioEQPreset.accentColor)
                            .frame(height: 12)

                        // Vertical Bar Container
                        ZStack(alignment: .center) {
                            // Center zero dB dotted guideline
                            Rectangle()
                                .fill(Color.white.opacity(0.15))
                                .frame(height: 1)

                            // Dynamic gain pill
                            let normalizedHeight = max(6.0, CGFloat(abs(gain) / 20.0) * 44.0 + 4.0)
                            let isPositive = gain >= 0

                            VStack(spacing: 0) {
                                if !isPositive {
                                    Spacer()
                                }

                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                store.audioEQPreset.accentColor,
                                                store.audioEQPreset.accentColor.opacity(0.4),
                                            ],
                                            startPoint: isPositive ? .top : .bottom,
                                            endPoint: isPositive ? .bottom : .top
                                        )
                                    )
                                    .frame(width: visualizerBarWidth, height: normalizedHeight)
                                    .shadow(color: store.audioEQPreset.accentColor.opacity(gain != 0 ? 0.4 : 0), radius: 4)

                                if isPositive {
                                    Spacer()
                                }
                            }
                            .frame(height: 52)
                        }
                        .frame(height: 52)

                        // Band Label
                        Text(label)
                            .font(.system(size: bandLabelFontSize, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.55))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black.opacity(0.45))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    }
            }
        }
    }

    // MARK: - Presets Grid

    private var presetsGrid: some View {
        let columns: [GridItem] = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
        ]

        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(AudioEQPreset.allCases) { preset in
                presetCard(preset)
            }
        }
    }

    private func presetCard(_ preset: AudioEQPreset) -> some View {
        let isSelected = store.audioEQPreset == preset

        return Button {
            #if !os(tvOS)
                HapticManager.shared.trigger(.light)
            #endif
            resetIdleTimer()
            store.send(.selectAudioEQPreset(preset))
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? preset.accentColor.opacity(0.25) : Color.white.opacity(0.06))
                        .frame(width: 38, height: 38)

                    Image(systemName: preset.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isSelected ? preset.accentColor : .white.opacity(0.85))
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(preset.title)
                            .font(.system(size: 14, weight: isSelected ? .bold : .semibold))
                            .foregroundColor(isSelected ? .white : .white.opacity(0.88))
                            .lineLimit(1)

                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(preset.accentColor)
                        }
                    }

                    Text(preset.subtitle)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? preset.accentColor.opacity(0.14) : Color.white.opacity(0.04))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                isSelected ? preset.accentColor.opacity(0.65) : Color.white.opacity(0.07),
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    }
            }
        }
        .buttonStyle(TVEQPresetButtonStyle(isSelected: isSelected, accentColor: preset.accentColor))
        #if os(tvOS)
            .focused($focusedPreset, equals: preset)
        #endif
    }

    // MARK: - Footer Info Bar

    private var footerInfoBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(store.audioEQPreset.accentColor)

            Text("Seçilen ses profili '\(store.item.title)' kanalı için otomatik hatırlanır.")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Idle Timer

    private func resetIdleTimer() {
        idleTimer?.cancel()
        let item = DispatchWorkItem { [onClose] in
            onClose()
        }
        idleTimer = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: item)
    }

    private func cancelIdleTimer() {
        idleTimer?.cancel()
        idleTimer = nil
    }

    // MARK: - Platform Layout Adaptations

    private var containerMaxWidth: CGFloat {
        #if os(tvOS)
            880
        #else
            480
        #endif
    }

    private var visualizerBarSpacing: CGFloat {
        #if os(tvOS)
            14
        #else
            8
        #endif
    }

    private var visualizerBarWidth: CGFloat {
        #if os(tvOS)
            18
        #else
            12
        #endif
    }

    private var bandLabelFontSize: CGFloat {
        #if os(tvOS)
            10
        #else
            8
        #endif
    }
}

// MARK: - tvOS Focusable Preset Button Style

private struct TVEQPresetButtonStyle: ButtonStyle {
    let isSelected: Bool
    let accentColor: Color

    func makeBody(configuration: Configuration) -> some View {
        TVEQPresetButtonBody(configuration: configuration, isSelected: isSelected, accentColor: accentColor)
    }

    private struct TVEQPresetButtonBody: View {
        let configuration: Configuration
        let isSelected: Bool
        let accentColor: Color
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            configuration.label
                .scaleEffect(isFocused ? 1.05 : 1.0)
                .overlay {
                    if isFocused {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(accentColor, lineWidth: 2.5)
                            .shadow(color: accentColor.opacity(0.6), radius: 10)
                    }
                }
                .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isFocused)
                .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
        }
    }
}
