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
        VStack(spacing: 18) {
            // Header bar
            headerBar

            // Mode Picker Tabs (Ses vs Altyazı)
            modePickerView

            // Main Display Card (Large readout, status pill, waveform)
            mainDisplayCard

            // Micro-Stepper Stepper Row (-250, -50, Reset, +50, +250)
            stepperRowView

            #if os(iOS)
                // Interactive Slider (-2000ms ... +2000ms)
                sliderControlView
            #endif

            // Channel Memory Persistence Checkbox
            rememberChannelRow
        }
        #if os(tvOS)
        .padding(32)
        .frame(width: 640)
        .background(
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Color(hex: "#0C0C10").opacity(0.92)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.7), radius: 30, x: 0, y: 15)
        .focusSection()
        .onExitCommand {
            cancelIdleTimer()
            onClose()
        }
        #else
        .padding(20)
        .frame(maxWidth: min(420, UIScreen.main.bounds.width - 32))
        .background(
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Color(hex: "#0C0C10").opacity(0.94)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.6), radius: 24, x: 0, y: 10)
        #endif
        .onAppear {
            resetIdleTimer()
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
                    .fill(Color(hex: "#0A84FF").opacity(0.2))
                    .frame(width: 34, height: 34)
                Image(systemName: "slider.horizontal.2.square")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(hex: "#0A84FF"))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(AppStrings.Player.lipSyncAdjustment)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text(AppStrings.Player.audioSyncSubtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer()

            Button {
                cancelIdleTimer()
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.75))
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.1), in: Circle())
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
                    .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        isSelected ?
                            Color(hex: "#0A84FF").opacity(0.8) :
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

    private var mainDisplayCard: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                // Status badge
                if currentDelay == 0 {
                    HStack(spacing: 4) {
                        Circle().fill(Color.green).frame(width: 6, height: 6)
                        Text(AppStrings.Player.synchronizedBadge)
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.15), in: Capsule())
                } else {
                    HStack(spacing: 4) {
                        Circle().fill(Color(hex: "#0A84FF")).frame(width: 6, height: 6)
                        Text(AppStrings.Player.adjustedBadge)
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundColor(Color(hex: "#0A84FF"))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(hex: "#0A84FF").opacity(0.18), in: Capsule())
                }
            }

            // Big readout
            Text(currentDelay == 0 ? "0 ms" : "\(currentDelay > 0 ? "+" : "")\(currentDelay) ms")
                .font(.system(size: 38, weight: .heavy, design: .monospaced))
                .foregroundColor(currentDelay == 0 ? .white : Color(hex: "#0A84FF"))
                .contentTransition(.numericText(value: Double(currentDelay)))
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: currentDelay)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color(hex: "#000000").opacity(0.6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Stepper Row View

    private var stepperRowView: some View {
        HStack(spacing: 8) {
            stepperButton(title: "-250", step: -250, focus: .stepMinus250)
            stepperButton(title: "-50", step: -50, focus: .stepMinus50)

            // Reset Button
            Button {
                #if !os(tvOS)
                    HapticManager.shared.trigger(.medium)
                #endif
                resetIdleTimer()
                applyDelay(0)
            } label: {
                Text(AppStrings.Player.resetSubtitleDelay)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            #if os(tvOS)
                .focused($focusedField, equals: .reset)
            #endif

            stepperButton(title: "+50", step: 50, focus: .stepPlus50)
            stepperButton(title: "+250", step: 250, focus: .stepPlus250)
        }
    }

    @ViewBuilder
    private func stepperButton(title: String, step: Int, focus: FocusField) -> some View {
        Button {
            #if !os(tvOS)
                HapticManager.shared.trigger(.light)
            #endif
            resetIdleTimer()
            let newDelay = max(-2000, min(2000, currentDelay + step))
            applyDelay(newDelay)
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        #if os(tvOS)
            .focused($focusedField, equals: focus)
        #endif
    }

    #if os(iOS)

        // MARK: - Slider Control View

        private var sliderControlView: some View {
            VStack(spacing: 4) {
                Slider(
                    value: Binding(
                        get: { Double(currentDelay) },
                        set: { newVal in
                            resetIdleTimer()
                            let rounded = (Int(newVal) / 50) * 50
                            applyDelay(rounded)
                        }
                    ),
                    in: -2000 ... 2000,
                    step: 50
                )
                .tint(Color(hex: "#0A84FF"))

                HStack {
                    Text("-2000 ms")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                    Spacer()
                    Text("0 ms")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                    Spacer()
                    Text("+2000 ms")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
        }
    #endif

    // MARK: - Channel Memory Persistence Row

    private var rememberChannelRow: some View {
        HStack(spacing: 10) {
            Image(systemName: store.rememberDelayForChannel ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(store.rememberDelayForChannel ? Color(hex: "#0A84FF") : .white.opacity(0.4))

            Text(AppStrings.Player.rememberForChannel)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.85))

            Spacer()

            #if os(iOS)
                Toggle("", isOn: Binding(
                    get: { store.rememberDelayForChannel },
                    set: { store.send(.setRememberDelayForChannel($0)) }
                ))
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#0A84FF")))
            #else
                Button {
                    resetIdleTimer()
                    store.send(.setRememberDelayForChannel(!store.rememberDelayForChannel))
                } label: {
                    Text(store.rememberDelayForChannel ? "Aktif" : "Pasif")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(store.rememberDelayForChannel ? Color(hex: "#0A84FF") : .white.opacity(0.6))
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

    // MARK: - Action Helpers

    private func applyDelay(_ delay: Int) {
        if syncMode == .audio {
            store.send(.setAudioDelay(delay))
        } else {
            store.send(.setSubtitleDelay(delay))
        }
    }

    private func resetIdleTimer() {
        cancelIdleTimer()
        let work = DispatchWorkItem {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                onClose()
            }
        }
        idleTimer = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0, execute: work)
    }

    private func cancelIdleTimer() {
        idleTimer?.cancel()
        idleTimer = nil
    }
}
