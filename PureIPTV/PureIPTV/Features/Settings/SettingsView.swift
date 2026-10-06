import ComposableArchitecture
import SwiftUI

public struct SettingsView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @Bindable var store: StoreOf<SettingsFeature>

    public init(store: StoreOf<SettingsFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            List {
                Section(header: Text(AppStrings.Settings.accounts)) {
                    Button(action: {
                        store.send(.managePlaylistsTapped)
                    }) {
                        HStack {
                            Image(systemName: "list.bullet.rectangle")
                                .foregroundColor(.blue)
                            Text(AppStrings.Settings.manageAccounts)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.primary)
                }

                Section(header: Text(AppStrings.Settings.security)) {
                    Toggle(isOn: Binding(
                        get: { store.isParentalControlEnabled },
                        set: { store.send(.toggleParentalControl($0)) }
                    )) {
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.red)
                            Text(AppStrings.ParentalLock.title)
                        }
                    }
                    .tint(.red)
                }

                Section(header: Text(AppStrings.Settings.appearance)) {
                    Picker(AppStrings.Settings.themeColor, selection: $theme.themeColorHex) {
                        ForEach(theme.availableColors, id: \.hex) { color in
                            HStack {
                                Circle().fill(Color(hex: color.hex)).frame(width: 16, height: 16)
                                Text(color.name)
                            }.tag(color.hex)
                        }
                    }
                    .onChange(of: theme.themeColorHex) { _, newValue in
                        theme.setThemeColor(hex: newValue)
                    }

                    Picker(AppStrings.Settings.appIcon, selection: $theme.currentAppIconName) {
                        ForEach(theme.availableIcons, id: \.name) { icon in
                            Text(icon.name).tag(icon.iconName ?? "AppIcon")
                        }
                    }
                    .onChange(of: theme.currentAppIconName) { _, newValue in
                        theme.setAppIcon(iconName: newValue == "AppIcon" ? nil : newValue)
                    }
                }

                Section(header: Text(AppStrings.Settings.about), footer: Text(AppStrings.Settings.appVersion)) {
                    HStack {
                        Text(AppStrings.Settings.version)
                        Spacer()
                        Text(AppStrings.Settings.versionNumber)
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle(AppStrings.Settings.title)
            .onAppear {
                store.send(.onAppear)
            }
            .sheet(isPresented: $store.isShowingPINSetup) {
                PINSetupView(store: store)
                #if os(iOS)
                    .presentationDetents([.height(300)])
                #endif
            }
        }
    }
}

struct PINSetupView: View {
    @Bindable var store: StoreOf<SettingsFeature>
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(store.step == .enterNew ? AppStrings.Settings.setNewPIN : AppStrings.Settings.verifyPIN)
                    .font(.headline)

                SecureField(AppStrings.ParentalLock.pin, text: Binding(
                    get: { store.step == .enterNew ? store.pinInput : store.pinConfirm },
                    set: { store.send(.pinInputChanged($0)) }
                ))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.largeTitle)
                .focused($isFocused)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)

                if let error = store.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.footnote)
                }

                Spacer()
            }
            .padding()
            .navigationTitle(AppStrings.ParentalLock.title)
            #if !os(tvOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(AppStrings.Common.cancel) {
                            store.send(.cancelPINSetup)
                        }
                    }
                }
                .onAppear {
                    isFocused = true
                }
        }
    }
}
