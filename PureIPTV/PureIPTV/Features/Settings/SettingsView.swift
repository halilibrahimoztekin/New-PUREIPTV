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

                    Button(action: {
                        store.send(.switchProfileTapped)
                    }) {
                        HStack {
                            Image(systemName: "person.2.circle")
                                .foregroundColor(.purple)
                            Text(AppStrings.Settings.switchProfile)
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

                    Toggle(isOn: Binding(
                        get: { store.hideAdultContent },
                        set: { store.send(.setHideAdultContent($0)) }
                    )) {
                        HStack {
                            Image(systemName: "eye.slash.fill")
                                .foregroundColor(.orange)
                            Text(AppStrings.Settings.hideAdultContent)
                        }
                    }
                    .tint(.orange)
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

                    Picker(AppStrings.Settings.startupScreen, selection: Binding(
                        get: { store.defaultStartupTab },
                        set: { store.send(.setDefaultStartupTab($0)) }
                    )) {
                        Text(AppStrings.Settings.discover).tag("Keşfet")
                        Text(AppStrings.LiveTV.title).tag("Canlı TV")
                        Text(AppStrings.VOD.title).tag("Filmler")
                        Text(AppStrings.Series.title).tag("Diziler")
                    }
                }

                Section(header: Text(AppStrings.Settings.contentSorting)) {
                    Picker(AppStrings.Settings.vodSorting, selection: Binding(
                        get: { store.vodSortMethod },
                        set: { store.send(.setVODSortMethod($0)) }
                    )) {
                        ForEach(SortMethod.allCases) { method in
                            Text(method.title).tag(method)
                        }
                    }

                    Picker(AppStrings.Series.title, selection: Binding(
                        get: { store.seriesSortMethod },
                        set: { store.send(.setSeriesSortMethod($0)) }
                    )) {
                        ForEach(SortMethod.allCases) { method in
                            Text(method.title).tag(method)
                        }
                    }
                }

                Section(header: Text(AppStrings.Settings.playerSettings)) {
                    Toggle(AppStrings.Settings.autoPlayNextEpisode, isOn: Binding(
                        get: { store.autoPlayNextEpisode },
                        set: { store.send(.setAutoPlayNextEpisode($0)) }
                    ))

                    Toggle(AppStrings.Settings.startMuted, isOn: Binding(
                        get: { store.startMuted },
                        set: { store.send(.setStartMuted($0)) }
                    ))

                    Toggle(AppStrings.Settings.hardwareAcceleration, isOn: Binding(
                        get: { store.hardwareAcceleration },
                        set: { store.send(.setHardwareAcceleration($0)) }
                    ))
                }

                Section(header: Text(AppStrings.Settings.epgSettings)) {
                    #if os(tvOS)
                        HStack {
                            Text(AppStrings.Settings.timeShift)
                            Spacer()
                            Button("-") { store.send(.setEpgTimeShift(max(-12, store.epgTimeShift - 1))) }
                            Text(AppStrings.Settings.timeShiftHours(store.epgTimeShift))
                                .foregroundColor(.gray)
                            Button("+") { store.send(.setEpgTimeShift(min(12, store.epgTimeShift + 1))) }
                        }
                    #else
                        Stepper(value: Binding(
                            get: { store.epgTimeShift },
                            set: { store.send(.setEpgTimeShift($0)) }
                        ), in: -12 ... 12) {
                            HStack {
                                Text(AppStrings.Settings.timeShift)
                                Spacer()
                                Text(AppStrings.Settings.timeShiftHours(store.epgTimeShift))
                                    .foregroundColor(.gray)
                            }
                        }
                    #endif

                    Toggle(AppStrings.Settings.autoUpdateEPG, isOn: Binding(
                        get: { store.autoUpdateEPG },
                        set: { store.send(.setAutoUpdateEPG($0)) }
                    ))
                }

                Section(header: Text(AppStrings.Settings.subscriptionAndStorage)) {
                    HStack {
                        Text(AppStrings.Settings.subscriptionStatus)
                        Spacer()
                        if store.isPremium {
                            Text(AppStrings.Settings.premiumStatus)
                                .foregroundColor(.orange)
                                .bold()
                        } else {
                            Text(AppStrings.Settings.freeStatus)
                                .foregroundColor(.gray)
                        }
                    }

                    if !store.isPremium {
                        Button(AppStrings.Paywall.restorePurchases) {
                            store.send(.restorePurchases)
                        }
                        .foregroundColor(.blue)
                    }

                    Button(action: {
                        store.send(.clearCache)
                    }) {
                        HStack {
                            Text(AppStrings.Settings.clearCache)
                            Spacer()
                            Text(store.cacheSize)
                                .foregroundColor(.gray)
                        }
                    }
                    .foregroundColor(.red)
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
