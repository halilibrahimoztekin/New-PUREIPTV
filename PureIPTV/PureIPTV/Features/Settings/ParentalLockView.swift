import ComposableArchitecture
import SwiftUI

public struct ParentalLockView: View {
    @Bindable var store: StoreOf<ParentalLockFeature>
    @FocusState private var isKeyboardFocused: Bool
    @FocusState private var focusedKeypadButton: String?

    public init(store: StoreOf<ParentalLockFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0F0F13").ignoresSafeArea()

                VStack(spacing: 20) {
                    Spacer(minLength: 10)

                    // Shield Icon
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.red)
                        .padding(.top, 10)

                    // Title & Description
                    VStack(spacing: 6) {
                        Text(AppStrings.ParentalLock.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text(AppStrings.ParentalLock.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        if store.pendingCategory != nil {
                            Text(AppStrings.ParentalLock.categoryUnlockNotice)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                    }

                    // 4-Digit PIN Indicators
                    pinDotsView
                        .padding(.vertical, 8)

                    // Error Message
                    if let error = store.errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.footnote)
                            Text(error)
                                .font(.footnote.weight(.semibold))
                        }
                        .foregroundColor(.red)
                        .transition(.opacity.combined(with: .scale))
                    }

                    #if os(tvOS)
                        // tvOS Focusable Numeric Keypad
                        tvOSKeypadView
                    #else
                        // iOS Hidden Native Keyboard Input
                        SecureField("", text: Binding(
                            get: { store.pinInput },
                            set: { store.send(.pinInputChanged($0)) }
                        ))
                        .keyboardType(.numberPad)
                        .focused($isKeyboardFocused)
                        .frame(width: 1, height: 1)
                        .opacity(0.01)

                        // iOS Biometric Retry Button
                        Button {
                            store.send(.onAppear)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "faceid")
                                    .font(.system(size: 18))
                                Text(AppStrings.ParentalLock.biometricReason)
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(Color.accentColor)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                        }
                        .padding(.top, 8)
                    #endif

                    Spacer(minLength: 10)
                }
            }
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppStrings.Common.cancel) {
                        store.send(.cancelTapped)
                    }
                    .foregroundColor(.secondary)
                }
            }
            #if os(tvOS)
            .onExitCommand {
                store.send(.cancelTapped)
            }
            #endif
            .onAppear {
                store.send(.onAppear)
                #if !os(tvOS)
                    isKeyboardFocused = true
                #endif
            }
        }
    }

    // MARK: - 4-Digit PIN Dots View

    private var pinDotsView: some View {
        HStack(spacing: 20) {
            ForEach(0 ..< 4, id: \.self) { index in
                let isFilled = store.pinInput.count > index
                ZStack {
                    Circle()
                        .stroke(isFilled ? Color.accentColor : Color.white.opacity(0.25), lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if isFilled {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 12, height: 12)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isFilled)
            }
        }
    }

    #if os(tvOS)

        // MARK: - tvOS Remote-Friendly Numeric Keypad

        private var tvOSKeypadView: some View {
            VStack(spacing: 12) {
                ForEach(0 ..< 3) { row in
                    HStack(spacing: 16) {
                        ForEach(1 ... 3, id: \.self) { col in
                            let digit = row * 3 + col
                            keypadButton(label: "\(digit)", action: { appendDigit("\(digit)") })
                        }
                    }
                }

                // Bottom row: Cancel / Clear, 0, Backspace
                HStack(spacing: 16) {
                    keypadButton(icon: "arrow.counterclockwise", action: {
                        store.send(.pinInputChanged(""))
                    })

                    keypadButton(label: "0", action: { appendDigit("0") })

                    keypadButton(icon: "delete.left.fill", action: {
                        if !store.pinInput.isEmpty {
                            store.send(.pinInputChanged(String(store.pinInput.dropLast())))
                        }
                    })
                }
            }
            .padding(.horizontal, 24)
        }

        private func keypadButton(label: String? = nil, icon: String? = nil, action: @escaping () -> Void) -> some View {
            let key = label ?? icon ?? ""
            return Button(action: action) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(focusedKeypadButton == key ? Color.white : Color.white.opacity(0.12))
                        .frame(width: 72, height: 48)

                    if let label {
                        Text(label)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(focusedKeypadButton == key ? .black : .white)
                    } else if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(focusedKeypadButton == key ? .black : .white)
                    }
                }
            }
            .buttonStyle(.plain)
            .focused($focusedKeypadButton, equals: key)
            .scaleEffect(focusedKeypadButton == key ? 1.12 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: focusedKeypadButton)
        }

        private func appendDigit(_ digit: String) {
            if store.pinInput.count < 4 {
                store.send(.pinInputChanged(store.pinInput + digit))
            }
        }
    #endif
}
