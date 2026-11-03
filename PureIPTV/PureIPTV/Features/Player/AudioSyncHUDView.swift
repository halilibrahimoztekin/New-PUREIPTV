import ComposableArchitecture
import SwiftUI

// MARK: - Lip-Sync & Subtitle Sync Micro-Adjustment HUD

public struct AudioSyncHUDView: View {
    @Bindable var store: StoreOf<PlayerFeature>
    let onClose: () -> Void

    public enum SyncMode: String, CaseIterable, Identifiable {
        case audio = "Ses"
        case subtitle = "Altyazı"

        public var id: String {
            rawValue
        }

        public var systemIcon: String {
            switch self {
            case .audio: "waveform.circle.fill"
            case .subtitle: "captions.bubble.fill"
            }
        }
    }

    @State private var syncMode: SyncMode = .audio
    @FocusState private var focusedField: FocusField?
    @State private var idleTimer: DispatchWorkItem?
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private func isLandscapeLayout(for size: CGSize) -> Bool {
        #if os(tvOS)
            return false
        #else
            return size.height < 520 || verticalSizeClass == .compact
        #endif
    }

    private enum FocusField: Hashable {
        case modePicker(SyncMode)
        case stepMinus250
        case stepMinus50
        case reset
        case stepPlus50
        case stepPlus250
        case rememberToggle
        case close
    }

    public init(store: StoreOf<PlayerFeature>, onClose: @escaping () -> Void) {
        self.store = store
        self.onClose = onClose
    }

    private var currentDelay: Int {
        syncMode == .audio ? store.audioDelay : store.subtitleDelay
    }

    public var body: some View {
        GeometryReader { geometry in
            let isCompact = isLandscapeLayout(for: geometry.size)

            VStack(spacing: isCompact ? 8 : 16) {
                // Header bar (pinned)
                headerBar(isCompact: isCompact)

                if isCompact {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 8) {
                            modePickerView
                            mainDisplayCard(isCompact: isCompact)
                            stepperRowView(isCompact: isCompact)
                            #if os(iOS)
                                sliderControlView
                            #endif
                            rememberChannelRow
                        }
                        .padding(.horizontal, 2)
                    }
                } else {
                    modePickerView
                    mainDisplayCard(isCompact: isCompact)
                    stepperRowView(isCompact: isCompact)
                    #if os(iOS)
                        sliderControlView
                    #endif
                    rememberChannelRow
                }
            }
            #if os(tvOS)
            .padding(32)
            .frame(width: 640)
            .background(
                ZStack {
                    Rectangle().fill(.ultraThinMaterial)
                    AppColors.surface.opacity(0.92)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AppColors.borderMedium, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.7), radius: 30, x: 0, y: 15)
            #else
            .padding(isCompact ? 12 : 20)
            .frame(maxWidth: isCompact ? min(520, geometry.size.width - 32) : min(420, UIScreen.main.bounds.width - 32))
            .frame(maxHeight: isCompact ? min(geometry.size.height - 20, 340) : nil)
            .background(
                ZStack {
                    Rectangle().fill(.ultraThinMaterial)
                    AppColors.surface.opacity(0.94)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AppColors.borderMedium, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.6), radius: 24, x: 0, y: 10)
            #endif
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        #if os(tvOS)
        .focusSection()
        .onExitCommand {
            cancelIdleTimer()
            onClose()
        }
        #endif
        .onAppear {
            resetIdleTimer()
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
                    .fill(AppColors.primary.opacity(0.2))
                    .frame(width: isCompact ? 30 : 34, height: isCompact ? 30 : 34)
                Image(systemName: "slider.horizontal.2.square")
                    .font(AppFonts.titleSmall)
                    .foregroundColor(AppColors.primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(AppStrings.Player.lipSyncAdjustment)
                    .font(isCompact ? AppFonts.bodySmall.weight(.bold) : AppFonts.titleSmall.weight(.bold))
                    .foregroundColor(AppColors.textPrimary)

                Text(AppStrings.Player.audioSyncSubtitle)
                    .font(AppFonts.captionSmall)
                    .foregroundColor(AppColors.textSecondary)
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
                    .frame(width: isCompact ? 28 : 32, height: isCompact ? 28 : 32)
                    .background(AppColors.surfaceSecondary, in: Circle())
            }
            .buttonStyle(.plain)
            #if os(tvOS)
                .focused($focusedField, equals: .close)
            #endif
        }
    }

    // MARK: - Mode Picker View

    private var modePickerView: some View {
        HStack(spacing: 8) {
            ForEach(SyncMode.allCases) { mode in
                let isSelected = syncMode == mode
                Button {
                    #if !os(tvOS)
                        HapticManager.shared.trigger(.light)
                    #endif
                    resetIdleTimer()
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                        syncMode = mode
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: mode.systemIcon)
                            .font(.system(size: 13, weight: .semibold))
                        Text(mode.rawValue)
                            .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                    }
                    .foregroundColor(isSelected ? AppColors.textPrimary : AppColors.textSecondary.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        isSelected ?
                            AppColors.primary.opacity(0.8) :
                            Color.white.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                #if os(tvOS)
                    .focused($focusedField, equals: .modePicker(mode))
                #endif
            }
        }
    }

    // MARK: - Main Readout Display Card

    private func mainDisplayCard(isCompact: Bool) -> some View {
        VStack(spacing: isCompact ? 4 : 8) {
            HStack {
                Spacer()
                // Status badge
                if currentDelay == 0 {
                    HStack(spacing: 4) {
                        Circle().fill(AppColors.success).frame(width: 6, height: 6)
                        Text(AppStrings.Player.synchronizedBadge)
                            .font(AppFonts.captionSmall)
                            .foregroundColor(AppColors.success)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppColors.success.opacity(0.15), in: Capsule())
                } else {
                    HStack(spacing: 4) {
                        Circle().fill(AppColors.primary).frame(width: 6, height: 6)
                        Text(AppStrings.Player.adjustedBadge)
                            .font(AppFonts.captionSmall)
                            .foregroundColor(AppColors.primary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppColors.primary.opacity(0.18), in: Capsule())
                }
            }

            // Big readout
            Text(currentDelay == 0 ? "0 ms" : "\(currentDelay > 0 ? "+" : "")\(currentDelay) ms")
                .font(.system(size: isCompact ? 28 : 38, weight: .heavy, design: .monospaced))
                .foregroundColor(currentDelay == 0 ? AppColors.textPrimary : AppColors.primary)
                .contentTransition(.numericText(value: Double(currentDelay)))
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: currentDelay)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, isCompact ? 8 : 12)
        .frame(maxWidth: .infinity)
        .background(AppColors.oledBlack.opacity(0.6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppColors.borderSubtle, lineWidth: 1)
        )
    }

    // MARK: - Stepper Row View

    private func stepperRowView(isCompact: Bool) -> some View {
        HStack(spacing: 8) {
            stepperButton(title: "-250", step: -250, focus: .stepMinus250, isCompact: isCompact)
            stepperButton(title: "-50", step: -50, focus: .stepMinus50, isCompact: isCompact)

            // Reset Button
            Button {
                #if !os(tvOS)
                    HapticManager.shared.trigger(.medium)
                #endif
                resetIdleTimer()
                applyDelay(0)
            } label: {
                Text(AppStrings.Player.resetSubtitleDelay)
                    .font(.system(size: isCompact ? 11 : 12, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, isCompact ? 7 : 10)
                    .background(Color.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            #if os(tvOS)
                .focused($focusedField, equals: .reset)
            #endif

            stepperButton(title: "+50", step: 50, focus: .stepPlus50, isCompact: isCompact)
            stepperButton(title: "+250", step: 250, focus: .stepPlus250, isCompact: isCompact)
        }
    }

    @ViewBuilder
    private func stepperButton(title: String, step: Int, focus: FocusField, isCompact: Bool) -> some View {
        Button {
            #if !os(tvOS)
                HapticManager.shared.trigger(.light)
            #endif
            resetIdleTimer()
            let newDelay = max(-2000, min(2000, currentDelay + step))
            applyDelay(newDelay)
        } label: {
            Text(title)
                .font(.system(size: isCompact ? 11 : 13, weight: .bold, design: .monospaced))
                .foregroundColor(AppColors.textPrimary.opacity(0.9))
                .frame(maxWidth: .infinity)
                .padding(.vertical, isCompact ? 7 : 10)
                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        #if os(tvOS)
            .focused($focusedField, equals: focus)
        #endif
    }

    // MARK: - Slider Control View (iOS / iPadOS Only)

    #if os(iOS)
        private var sliderControlView: some View {
            VStack(spacing: 4) {
                Slider(
                    value: Binding<Double>(
                        get: { Double(currentDelay) },
                        set: { newValue in
                            resetIdleTimer()
                            applyDelay(Int(newValue.rounded()))
                        }
                    ),
                    in: -2000 ... 2000,
                    step: 25
                )
                .tint(AppColors.primary)

                HStack {
                    Text("-2000 ms")
                        .font(AppFonts.captionSmall)
                        .foregroundColor(AppColors.textSecondary.opacity(0.6))
                    Spacer()
                    Text("0 ms")
                        .font(AppFonts.captionSmall)
                        .foregroundColor(AppColors.textSecondary.opacity(0.6))
                    Spacer()
                    Text("+2000 ms")
                        .font(AppFonts.captionSmall)
                        .foregroundColor(AppColors.textSecondary.opacity(0.6))
                }
            }
            .padding(.horizontal, 4)
        }
    #endif

    // MARK: - Remember Channel Row

    private var rememberChannelRow: some View {
        HStack(spacing: 10) {
            Image(systemName: store.rememberDelayForChannel ? "checkmark.circle.fill" : "circle")
                .font(AppFonts.bodySmall)
                .foregroundColor(store.rememberDelayForChannel ? AppColors.primary : AppColors.textSecondary.opacity(0.4))

            Text(AppStrings.Player.rememberForChannel)
                .font(AppFonts.captionSmall)
                .foregroundColor(AppColors.textPrimary.opacity(0.85))

            Spacer()

            #if os(iOS)
                Toggle("", isOn: Binding(
                    get: { store.rememberDelayForChannel },
                    set: { store.send(.setRememberDelayForChannel($0)) }
                ))
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: AppColors.primary))
            #else
                Button {
                    resetIdleTimer()
                    store.send(.setRememberDelayForChannel(!store.rememberDelayForChannel))
                } label: {
                    Text(store.rememberDelayForChannel ? "Aktif" : "Pasif")
                        .font(AppFonts.captionBold)
                        .foregroundColor(store.rememberDelayForChannel ? AppColors.primary : AppColors.textSecondary.opacity(0.6))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
                .focused($focusedField, equals: .rememberToggle)
            #endif
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Delay Dispatch

    private func applyDelay(_ delay: Int) {
        if syncMode == .audio {
            store.send(.setAudioDelay(delay))
        } else {
            store.send(.setSubtitleDelay(delay))
        }
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
}
