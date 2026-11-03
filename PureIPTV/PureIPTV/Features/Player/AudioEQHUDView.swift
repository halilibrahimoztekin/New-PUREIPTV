import ComposableArchitecture
import SwiftUI

// MARK: - Live Stream Audio Equalizer Presets & Dialogue Enhancer HUD (Madde #14)

public struct AudioEQHUDView: View {
    @Bindable var store: StoreOf<PlayerFeature>
    let onClose: () -> Void

    @FocusState private var focusedPreset: AudioEQPreset?
    @FocusState private var isCloseFocused: Bool
    @State private var idleTimer: DispatchWorkItem?
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    public init(store: StoreOf<PlayerFeature>, onClose: @escaping () -> Void) {
        self.store = store
        self.onClose = onClose
    }

    private func isLandscapeLayout(for size: CGSize) -> Bool {
        #if os(tvOS)
            return false
        #else
            return size.height < 520 || verticalSizeClass == .compact
        #endif
    }

    public var body: some View {
        GeometryReader { geometry in
            let isCompact = isLandscapeLayout(for: geometry.size)

            VStack(spacing: isCompact ? 8 : 16) {
                // Header Bar (Pinned, always visible)
                headerBar(isCompact: isCompact)

                if isCompact {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 8) {
                            eqFrequencyVisualizer(isCompact: isCompact)
                            presetsGrid(isCompact: isCompact)
                            footerInfoBar
                        }
                        .padding(.horizontal, 2)
                    }
                } else {
                    eqFrequencyVisualizer(isCompact: isCompact)
                    presetsGrid(isCompact: isCompact)
                    footerInfoBar
                }
            }
            .padding(isCompact ? 12 : 24)
            .frame(maxWidth: isCompact ? min(680, geometry.size.width - 32) : containerMaxWidth)
            #if !os(tvOS)
                .frame(maxHeight: isCompact ? min(geometry.size.height - 20, 350) : nil)
            #endif
                .background {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(AppColors.surface.opacity(0.95))
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
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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

    private func headerBar(isCompact: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(store.audioEQPreset.accentColor.opacity(0.18))
                    .frame(width: isCompact ? 30 : 42, height: isCompact ? 30 : 42)

                Image(systemName: "waveform.badge.magnifyingglass")
                    .font(.system(size: isCompact ? 14 : 19, weight: .semibold))
                    .foregroundColor(store.audioEQPreset.accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("Ses Ekolayzer & Diyalog")
                        .font(isCompact ? AppFonts.bodySmall.weight(.bold) : AppFonts.titleSmall.weight(.bold))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)

                    Text("PRO")
                        .font(AppFonts.captionSmall.weight(.heavy))
                        .foregroundColor(AppColors.oledBlack)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(store.audioEQPreset.accentColor, in: Capsule())
                }

                Text("İçeriğe özel sinematik ses optimizasyonu")
                    .font(AppFonts.captionSmall)
                    .foregroundColor(AppColors.textSecondary.opacity(0.65))
                    .lineLimit(1)
            }

            Spacer()

            Button {
                cancelIdleTimer()
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: isCompact ? 11 : 12, weight: .bold))
                    .foregroundColor(AppColors.textPrimary.opacity(0.85))
                    .frame(width: isCompact ? 28 : 34, height: isCompact ? 28 : 34)
                    .background(AppColors.surfaceSecondary, in: Circle())
            }
            .buttonStyle(.plain)
            #if os(tvOS)
                .focused($isCloseFocused)
            #endif
        }
    }

    // MARK: - 10-Band EQ Frequency Visualizer

    private func eqFrequencyVisualizer(isCompact: Bool) -> some View {
        let barHeight: CGFloat = isCompact ? 28 : 52
        let maxNormalized: CGFloat = isCompact ? 22 : 44

        return VStack(spacing: isCompact ? 4 : 10) {
            HStack(alignment: .bottom, spacing: isCompact ? 6 : visualizerBarSpacing) {
                ForEach(0 ..< AudioEQPreset.bandFrequencies.count, id: \.self) { index in
                    let label = AudioEQPreset.bandFrequencies[index]
                    let gain = store.audioEQPreset.bandGains[index]

                    VStack(spacing: isCompact ? 2 : 4) {
                        Text(String(format: "%+.0f", gain))
                            .font(.system(size: isCompact ? 7.5 : bandLabelFontSize, weight: .bold, design: .monospaced))
                            .foregroundColor(gain != 0 ? store.audioEQPreset.accentColor : AppColors.textSecondary.opacity(0.45))

                        GeometryReader { _ in
                            let normalizedHeight = max(2, min(maxNormalized, (CGFloat(abs(gain)) / 12.0) * maxNormalized))
                            let isPositive = gain >= 0

                            VStack(spacing: 0) {
                                if !isPositive {
                                    Spacer()
                                }

                                RoundedRectangle(cornerRadius: isCompact ? 2 : 3, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: isPositive
                                                ? [store.audioEQPreset.accentColor, store.audioEQPreset.accentColor.opacity(0.6)]
                                                : [Color.orange.opacity(0.6), Color.orange],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: isCompact ? 8 : visualizerBarWidth, height: normalizedHeight)
                                    .shadow(color: store.audioEQPreset.accentColor.opacity(gain != 0 ? 0.4 : 0), radius: 4)

                                if isPositive {
                                    Spacer()
                                }
                            }
                            .frame(height: barHeight)
                        }
                        .frame(height: barHeight)

                        Text(label)
                            .font(.system(size: isCompact ? 7.5 : bandLabelFontSize, weight: .medium, design: .rounded))
                            .foregroundColor(AppColors.textSecondary.opacity(0.55))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, isCompact ? 6 : 12)
            .padding(.horizontal, isCompact ? 8 : 14)
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

    private func presetsGrid(isCompact: Bool) -> some View {
        let columns: [GridItem] = if isCompact {
            [
                GridItem(.flexible(), spacing: 6),
                GridItem(.flexible(), spacing: 6),
                GridItem(.flexible(), spacing: 6),
            ]
        } else {
            [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
            ]
        }

        return LazyVGrid(columns: columns, spacing: isCompact ? 6 : 12) {
            ForEach(AudioEQPreset.allCases) { preset in
                presetCard(preset, isCompact: isCompact)
            }
        }
    }

    private func presetCard(_ preset: AudioEQPreset, isCompact: Bool) -> some View {
        let isSelected = store.audioEQPreset == preset

        return Button {
            #if !os(tvOS)
                HapticManager.shared.trigger(.light)
            #endif
            resetIdleTimer()
            store.send(.selectAudioEQPreset(preset))
        } label: {
            HStack(spacing: isCompact ? 6 : 12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? preset.accentColor.opacity(0.25) : Color.white.opacity(0.06))
                        .frame(width: isCompact ? 24 : 38, height: isCompact ? 24 : 38)

                    Image(systemName: preset.icon)
                        .font(.system(size: isCompact ? 11 : 16, weight: .semibold))
                        .foregroundColor(isSelected ? preset.accentColor : AppColors.textPrimary.opacity(0.85))
                }

                VStack(alignment: .leading, spacing: isCompact ? 1 : 3) {
                    HStack(spacing: 4) {
                        Text(preset.title)
                            .font(.system(size: isCompact ? 10.5 : 14, weight: isSelected ? .bold : .semibold))
                            .foregroundColor(isSelected ? AppColors.textPrimary : AppColors.textPrimary.opacity(0.88))
                            .lineLimit(1)

                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: isCompact ? 9 : 12, weight: .bold))
                                .foregroundColor(preset.accentColor)
                        }
                    }

                    Text(preset.subtitle)
                        .font(.system(size: isCompact ? 8.5 : 11, weight: .regular))
                        .foregroundColor(AppColors.textSecondary.opacity(0.65))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, isCompact ? 8 : 14)
            .padding(.vertical, isCompact ? 6 : 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? preset.accentColor.opacity(0.14) : Color.white.opacity(0.04))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
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
                .font(AppFonts.captionSmall)
                .foregroundColor(AppColors.textSecondary.opacity(0.7))
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
            640
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
            #if os(tvOS)
                .tvHighContrastFocusOutline(isFocused: isFocused, shape: .roundedRectangle(cornerRadius: 14))
            #endif
        }
    }
}
