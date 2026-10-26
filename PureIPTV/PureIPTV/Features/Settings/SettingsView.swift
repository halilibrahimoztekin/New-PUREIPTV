import ComposableArchitecture
import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

public struct SettingsView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var accountInfoManager = AccountInfoManager.shared
    @ObservedObject private var userAgentManager = UserAgentManager.shared
    @Bindable var store: StoreOf<SettingsFeature>

    @State private var isShowingSpeedTest: Bool = false
    @State private var backupExportURL: URL? = nil
    @State private var backupAlertMessage: String? = nil
    @State private var isShowingBackupAlert: Bool = false
    @State private var diagnosticReportURL: URL?
    @State private var isGeneratingDiagnosticReport = false
    @State private var isShowingTraktWatchlist: Bool = false
    #if os(tvOS)
        @AppStorage("com.pureiptv.tvOSPlayerRemoteUpAction") private var playerRemoteUpAction = TVPlayerRemoteAction.channelUp.rawValue
        @AppStorage("com.pureiptv.tvOSPlayerRemoteDownAction") private var playerRemoteDownAction = TVPlayerRemoteAction.channelDown.rawValue
        @AppStorage("com.pureiptv.tvOSPlayerRemoteLeftAction") private var playerRemoteLeftAction = TVPlayerRemoteAction.openChannelList.rawValue
        @AppStorage("com.pureiptv.tvOSPlayerRemoteRightAction") private var playerRemoteRightAction = TVPlayerRemoteAction.recallLastChannel.rawValue
    #endif

    public init(store: StoreOf<SettingsFeature>) {
        self.store = store
    }

    public var body: some View {
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

                // Madde #75 & #76: Xtream Account Expiration & Connection Limit
                if let info = accountInfoManager.accountInfo {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Abonelik Bitişi", systemImage: "calendar.badge.clock")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(info.formattedExpiration)
                                .font(.subheadline.bold())
                                .foregroundColor(info.isExpiringSoon ? .orange : .primary)
                        }

                        HStack {
                            Label("Bağlantı Limiti", systemImage: "network.badge.shield.half.filled")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(info.connectionsDescription)
                                .font(.subheadline.bold())
                                .foregroundColor(info.isLimitReached ? .red : .primary)
                        }
                    }
                    .padding(.vertical, 4)
                }
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

                Button {
                    store.send(.openHiddenContentManagement)
                } label: {
                    HStack {
                        Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                            .foregroundColor(Color(hex: "#0A84FF"))
                        Text("Gizlenen Kanallar & Kategoriler")
                            .foregroundColor(.primary)
                        Spacer()
                        if (store.hiddenChannelsCount + store.blacklistedCategoriesCount) > 0 {
                            Text("\(store.hiddenChannelsCount + store.blacklistedCategoriesCount)")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color(hex: "#0A84FF"), in: Capsule())
                        }
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                }
            }

            Section(header: Text(AppStrings.Settings.appearance)) {
                Picker(AppStrings.Settings.visualThemePreset, selection: Binding(
                    get: { theme.selectedPresetID },
                    set: { theme.setThemePreset(id: $0) }
                )) {
                    ForEach(theme.availablePresets) { preset in
                        HStack(spacing: 10) {
                            Circle().fill(preset.accentColor).frame(width: 16, height: 16)
                            Text(preset.name)
                        }
                        .tag(preset.id)
                    }
                }
                Text(AppStrings.Settings.visualThemePresetDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker(AppStrings.Settings.appIcon, selection: $theme.currentAppIconName) {
                    ForEach(theme.availableIcons, id: \.name) { icon in
                        Text(icon.name).tag(icon.iconName ?? "AppIcon")
                    }
                }
                .onChange(of: theme.currentAppIconName) { _, newValue in
                    theme.setAppIcon(iconName: newValue == "AppIcon" ? nil : newValue)
                }

                #if os(tvOS)
                    Toggle(AppStrings.Settings.twoLineTVChannelTitles, isOn: Binding(
                        get: { store.showTwoLineTVChannelTitles },
                        set: { store.send(.setShowTwoLineTVChannelTitles($0)) }
                    ))
                #endif

                Picker(AppStrings.Settings.startupScreen, selection: Binding(
                    get: { store.defaultStartupTab },
                    set: { store.send(.setDefaultStartupTab($0)) }
                )) {
                    Text(AppStrings.Settings.discover).tag("Keşfet")
                    Text(AppStrings.LiveTV.title).tag("Canlı TV")
                    Text(AppStrings.VOD.title).tag("Filmler")
                    Text(AppStrings.Series.title).tag("Diziler")
                }

                Toggle(AppStrings.Settings.hideEmptyContentTabs, isOn: Binding(
                    get: { store.hideEmptyContentTabs },
                    set: { store.send(.setHideEmptyContentTabs($0)) }
                ))
                Text(AppStrings.Settings.hideEmptyContentTabsDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Yalnızca Canlı TV gezinmesi", isOn: Binding(
                    get: { store.liveTVOnlyNavigation },
                    set: { store.send(.setLiveTVOnlyNavigation($0)) }
                ))
                Text("Ana gezinmede Canlı TV ve Ayarlar sekmelerini gösterir. Film ve dizi kitaplıkların korunur; bu sekmeler ayar kapatılınca yeniden görünür.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

                Toggle(AppStrings.Settings.autoSelectFirstAlternativeSource, isOn: Binding(
                    get: { store.autoSelectFirstAlternativeSource },
                    set: { store.send(.setAutoSelectFirstAlternativeSource($0)) }
                ))
                Text(AppStrings.Settings.autoSelectFirstAlternativeSourceDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle(AppStrings.Settings.reverseChannelZappingDirection, isOn: Binding(
                    get: { store.reverseChannelZappingDirection },
                    set: { store.send(.setReverseChannelZappingDirection($0)) }
                ))
                Text(AppStrings.Settings.reverseChannelZappingDirectionDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                #if os(tvOS)
                    Text(AppStrings.Settings.remoteControls)
                        .font(.headline)
                    Picker(AppStrings.Settings.remoteDirectionUp, selection: $playerRemoteUpAction) {
                        ForEach(TVPlayerRemoteAction.allCases) { action in
                            Text(action.title).tag(action.rawValue)
                        }
                    }
                    Picker(AppStrings.Settings.remoteDirectionDown, selection: $playerRemoteDownAction) {
                        ForEach(TVPlayerRemoteAction.allCases) { action in
                            Text(action.title).tag(action.rawValue)
                        }
                    }
                    Picker(AppStrings.Settings.remoteDirectionLeft, selection: $playerRemoteLeftAction) {
                        ForEach(TVPlayerRemoteAction.allCases) { action in
                            Text(action.title).tag(action.rawValue)
                        }
                    }
                    Picker(AppStrings.Settings.remoteDirectionRight, selection: $playerRemoteRightAction) {
                        ForEach(TVPlayerRemoteAction.allCases) { action in
                            Text(action.title).tag(action.rawValue)
                        }
                    }
                    Text(AppStrings.Settings.remoteControlsDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                #endif

                Toggle(AppStrings.Settings.startMuted, isOn: Binding(
                    get: { store.startMuted },
                    set: { store.send(.setStartMuted($0)) }
                ))

                #if os(iOS)
                    Picker(AppStrings.Settings.downloadConcurrencyLimit, selection: Binding(
                        get: { store.downloadConcurrencyLimit },
                        set: { store.send(.setDownloadConcurrencyLimit($0)) }
                    )) {
                        ForEach(1 ... 4, id: \.self) { limit in
                            Text("\(limit)").tag(limit)
                        }
                    }
                    Text(AppStrings.Settings.downloadConcurrencyLimitDesc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                #endif

                Picker("Film ve Dizi Arabellek Boyutu", selection: Binding(
                    get: { store.bufferProfile },
                    set: { store.send(.setBufferProfile($0)) }
                )) {
                    ForEach(BufferProfile.allCases, id: \.self) { profile in
                        Text(profile.rawValue).tag(profile)
                    }
                }

                Text("Yüksek arabellek yavaş bağlantılarda kesintiyi azaltabilir; ilk oynatma biraz daha uzun sürebilir. Yalnızca film ve dizi akışlarında kullanılır.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle(AppStrings.Settings.oledDimming, isOn: Binding(
                    get: { store.isOLEDDimmingEnabled },
                    set: { store.send(.setOLEDDimmingEnabled($0)) }
                ))

                Toggle(AppStrings.Settings.cleanChannelNames, isOn: Binding(
                    get: { store.isChannelNameCleaningEnabled },
                    set: { store.send(.setChannelNameCleaningEnabled($0)) }
                ))
            }

            Section(header: Text("Ekran & Kare Hızı Eşleme (AFR)")) {
                Toggle("Canlı TV için Kare Hızı Eşleme", isOn: Binding(
                    get: { store.isAFREnabledForLive },
                    set: { store.send(.setAFREnabledForLive($0)) }
                ))

                Toggle("Filmler ve Diziler için Kare Hızı Eşleme", isOn: Binding(
                    get: { store.isAFREnabledForVOD },
                    set: { store.send(.setAFREnabledForVOD($0)) }
                ))

                Toggle("Dinamik Aralık Eşleme (HDR / Dolby Vision)", isOn: Binding(
                    get: { store.isMatchDynamicRangeEnabled },
                    set: { store.send(.setMatchDynamicRangeEnabled($0)) }
                ))

                Text("Canlı yayınlar ve filmler/diziler için eşlemeyi ayrı ayrı açın. Etkin olduğunda içerik kare hızı (24p, 50/60 Hz) ve HDR renk aralığıyla ekran yenileme hızı eşlenir.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            #if os(tvOS)
                Section(header: Text("Apple TV Top Shelf Vitrin Modu")) {
                    Picker("Top Shelf Vitrin Düzeni", selection: Binding(
                        get: { store.topShelfStyle },
                        set: { store.send(.setTopShelfStyle($0)) }
                    )) {
                        ForEach(TopShelfStyle.allCases, id: \.self) { style in
                            Text(style.title).tag(style)
                        }
                    }

                    Text("Apple TV ana ekranında uygulama simgesi üzerindeyken gösterilecek vitrin stili (Bölümlü Liste veya Tam Ekran Carousel).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            #endif

            Section(header: Text("Resim İçinde Resim (PiP) & Arka Plan")) {
                Toggle("Arka Plana Geçince Otomatik PiP", isOn: Binding(
                    get: { store.isAutoPiPEnabled },
                    set: { store.send(.setAutoPiPEnabled($0)) }
                ))

                Picker("Arka Planda Oynatma Modu", selection: Binding(
                    get: { store.backgroundPlaybackMode },
                    set: { store.send(.setBackgroundPlaybackMode($0)) }
                )) {
                    ForEach(BackgroundPlaybackMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.icon)
                            .tag(mode)
                    }
                }

                Text(store.backgroundPlaybackMode.descriptionText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(header: Text(AppStrings.Settings.audioAndSubtitleSettings)) {
                Picker(AppStrings.Settings.defaultAudioLanguage, selection: Binding(
                    get: { store.preferredAudioLanguage },
                    set: { store.send(.setPreferredAudioLanguage($0)) }
                )) {
                    Text("🇹🇷 Türkçe").tag("tr")
                    Text("🇬🇧 English").tag("en")
                    Text("🇩🇪 Deutsch").tag("de")
                    Text("🇫🇷 Français").tag("fr")
                    Text("🇪🇸 Español").tag("es")
                    Text("🇮🇹 Italiano").tag("it")
                    Text("🇷🇺 Русский").tag("ru")
                    Text("🇸🇦 العربية").tag("ar")
                    Text("Orijinal").tag("und")
                }

                Picker(AppStrings.Settings.defaultSubtitleLanguage, selection: Binding(
                    get: { store.preferredSubtitleLanguage },
                    set: { store.send(.setPreferredSubtitleLanguage($0)) }
                )) {
                    Text(AppStrings.Player.off).tag("off")
                    Text("🇹🇷 Türkçe").tag("tr")
                    Text("🇬🇧 English").tag("en")
                    Text("🇩🇪 Deutsch").tag("de")
                    Text("🇫🇷 Français").tag("fr")
                    Text("🇪🇸 Español").tag("es")
                    Text("🇷🇺 Русский").tag("ru")
                    Text("🇸🇦 العربية").tag("ar")
                }

                Picker(AppStrings.Settings.subtitleTextSize, selection: Binding(
                    get: { store.subtitleTextSize },
                    set: { store.send(.setSubtitleTextSize($0)) }
                )) {
                    ForEach(SubtitleTextSize.allCases) { size in
                        Text(size.title).tag(size)
                    }
                }
                Text(AppStrings.Settings.subtitleTextSizeDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle(AppStrings.Settings.rememberTrackPreferences, isOn: Binding(
                    get: { store.rememberMediaTrackPreferences },
                    set: { store.send(.setRememberMediaTrackPreferences($0)) }
                ))
            }

            Section(header: Text(AppStrings.Settings.epgSettings)) {
                #if os(iOS)
                    Toggle(AppStrings.Player.autoSwitchReminder, isOn: Binding(
                        get: { store.autoSwitchOnEPGReminder },
                        set: { store.send(.setAutoSwitchOnEPGReminder($0)) }
                    ))
                    Text(AppStrings.Player.autoSwitchReminderDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                #endif

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

                Picker(AppStrings.Settings.epgAutoRefreshInterval, selection: Binding(
                    get: { store.epgAutoRefreshInterval },
                    set: { store.send(.setEPGAutoRefreshInterval($0)) }
                )) {
                    ForEach(EPGAutoRefreshInterval.allCases) { interval in
                        Text(interval.title).tag(interval)
                    }
                }
                .disabled(!store.autoUpdateEPG)
                Text(AppStrings.Settings.epgAutoRefreshDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button {
                    store.send(.setCustomEPGSheetPresented(true))
                } label: {
                    HStack {
                        Label("Özel XMLTV Kaynakları & Eşleme", systemImage: "clock.arrow.2.circlepath")
                            .foregroundStyle(.white)
                        Spacer()
                        if !store.customEPGSources.isEmpty {
                            Text("\(store.customEPGSources.count) kaynak")
                                .font(.caption)
                                .foregroundStyle(Color(hex: "#0A84FF"))
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section(header: Text(AppStrings.Settings.cloudSyncSection), footer: Text(AppStrings.Settings.iCloudSyncDesc)) {
                Toggle(isOn: Binding(
                    get: { store.isICloudSyncEnabled },
                    set: { store.send(.setICloudSyncEnabled($0)) }
                )) {
                    Label {
                        Text(AppStrings.Settings.iCloudSync)
                    } icon: {
                        Image(systemName: "icloud.fill")
                            .foregroundColor(.blue)
                    }
                }

                if store.isICloudSyncEnabled {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Son Senkronizasyon")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let lastSync = store.lastCloudSyncDate {
                                Text(lastSync, style: .relative)
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                            } else {
                                Text("Henüz senkronize edilmedi")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Button {
                            store.send(.syncNowTapped)
                        } label: {
                            HStack(spacing: 6) {
                                if store.isCloudSyncing {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath.icloud.fill")
                                        .font(.caption)
                                    Text("Şimdi Eşitle")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color(hex: "#0A84FF").opacity(0.15))
                            )
                            .foregroundStyle(Color(hex: "#0A84FF"))
                        }
                        #if !os(tvOS)
                        .buttonStyle(.plain)
                        #endif
                        .disabled(store.isCloudSyncing)
                    }

                    if let summary = store.cloudSyncSummary {
                        HStack(spacing: 12) {
                            Label("\(summary.favoritesCount) Favori", systemImage: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(Color(hex: "#FFD60A"))

                            Label("\(summary.hiddenChannelsCount) Gizli", systemImage: "eye.slash.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            Label("\(summary.watchProgressCount) İlerleme", systemImage: "play.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(Color(hex: "#30D158"))
                        }
                        .padding(.vertical, 2)
                    }

                    if let msg = store.cloudSyncMessage {
                        Text(msg)
                            .font(.caption2)
                            .foregroundStyle(store.cloudSyncMessage?.contains("hata") == true ? Color.red : Color(hex: "#30D158"))
                    }
                }
            }

            // Trakt.tv Integration (Madde #17)
            Section(
                header: Text("Trakt.tv Senkronizasyonu"),
                footer: Text("VOD film ve dizi ilerlemelerinizi Trakt.tv ile gerçek zamanlı eşitleyin.")
            ) {
                if store.isTraktAuthenticated {
                    HStack {
                        Image(systemName: "tv.badge.wifi")
                            .foregroundColor(Color(hex: "#ED1C24"))
                        Text("Bağlı Hesap")
                        Spacer()
                        Text(store.traktUsername ?? "Kullanıcı")
                            .foregroundColor(Color(hex: "#ED1C24"))
                            .bold()
                    }

                    Toggle("Otomatik Scrobble", isOn: Binding(
                        get: { store.isTraktAutoScrobbleEnabled },
                        set: { store.send(.toggleTraktAutoScrobble($0)) }
                    ))
                    .tint(Color(hex: "#ED1C24"))

                    Button {
                        isShowingTraktWatchlist = true
                    } label: {
                        HStack {
                            Image(systemName: "bookmark.fill")
                                .foregroundColor(Color(hex: "#ED1C24"))
                            Text("İzleme Listesi & Devam Edenler")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.primary)

                    Button(role: .destructive) {
                        store.send(.traktLogout)
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Trakt Hesabından Çıkış Yap")
                        }
                    }
                } else {
                    Button {
                        store.send(.setTraktAuthSheetPresented(true))
                    } label: {
                        HStack {
                            Image(systemName: "tv.badge.wifi")
                                .foregroundColor(Color(hex: "#ED1C24"))
                            Text("Trakt.tv ile Bağlan")
                                .fontWeight(.semibold)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                    }
                }
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

                Button(role: .destructive) {
                    #if os(iOS)
                        HapticManager.shared.trigger(.light)
                    #endif
                    store.send(.clearCacheTapped)
                } label: {
                    HStack {
                        Label(AppStrings.Settings.clearCache, systemImage: "trash")
                        Spacer()
                        if store.cacheSize == AppStrings.Settings.calculating || store.cacheSize == AppStrings.Settings.clearing {
                            ProgressView()
                                .scaleEffect(0.8)
                                .padding(.trailing, 4)
                        }
                        Text(store.cacheSize)
                            .foregroundColor(.secondary)
                    }
                }
                .foregroundColor(.red)
            }

            Section(header: Text("Ağ, Hız & Oynatıcı Teşhisi")) {
                Button(action: {
                    isShowingSpeedTest = true
                }) {
                    HStack {
                        Image(systemName: "speedometer")
                            .foregroundColor(.cyan)
                        Text("Sunucu Hız ve Ping Testi")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                }
                .foregroundColor(.primary)

                Picker("Özel User-Agent", selection: $userAgentManager.currentPreset) {
                    ForEach(UserAgentPreset.allCases) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }

                if userAgentManager.currentPreset == .custom {
                    TextField("User-Agent Dizgisi", text: $userAgentManager.customUserAgentString)
                        .font(.caption)
                }
            }

            Section(header: Text("Yedekleme & Geri Bildirim")) {
                Button(action: {
                    do {
                        let url = try BackupManager.shared.createBackupFile()
                        backupExportURL = url
                        backupAlertMessage = "Yedek dosyası başarıyla oluşturuldu:\n\(url.lastPathComponent)"
                        isShowingBackupAlert = true
                    } catch {
                        backupAlertMessage = "Yedekleme oluşturulamadı: \(error.localizedDescription)"
                        isShowingBackupAlert = true
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.down.doc.fill")
                            .foregroundColor(.green)
                        Text("Ayarları Yedekle (.iptvbackup)")
                    }
                }
                .foregroundColor(.primary)

                Button(action: {
                    Task {
                        guard !isGeneratingDiagnosticReport else { return }
                        isGeneratingDiagnosticReport = true
                        defer { isGeneratingDiagnosticReport = false }
                        if let reportURL = await FeedbackReportManager.shared.generateDiagnosticReport() {
                            if let previousURL = diagnosticReportURL {
                                try? FileManager.default.removeItem(at: previousURL)
                            }
                            diagnosticReportURL = reportURL
                        }
                    }
                }) {
                    HStack {
                        if isGeneratingDiagnosticReport {
                            ProgressView()
                        } else {
                            Image(systemName: "doc.text.magnifyingglass")
                                .foregroundColor(.indigo)
                        }
                        Text(isGeneratingDiagnosticReport
                            ? AppStrings.Settings.diagnosticReportGenerating
                            : AppStrings.Settings.createDiagnosticReport)
                    }
                }
                .disabled(isGeneratingDiagnosticReport)
                .accessibilityLabel(AppStrings.Settings.createDiagnosticReport)
                .accessibilityHint(AppStrings.Settings.diagnosticReportHint)
                .foregroundColor(.primary)
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
        .alert(
            AppStrings.Settings.clearCacheTitle,
            isPresented: $store.isShowingClearCacheConfirmation
        ) {
            Button(AppStrings.Settings.clearCacheConfirm, role: .destructive) {
                store.send(.confirmClearCache)
            }
            Button(AppStrings.Common.cancel, role: .cancel) {
                store.send(.cancelClearCache)
            }
        } message: {
            Text(AppStrings.Settings.clearCacheMessage)
        }
        .alert(
            AppStrings.Settings.clearCacheTitle,
            isPresented: $store.isShowingClearCacheSuccess
        ) {
            Button(AppStrings.Common.ok, role: .cancel) {
                store.send(.clearCacheSuccessDismissed)
            }
        } message: {
            Text(AppStrings.Settings.clearCacheSuccess)
        }
        .sheet(isPresented: $store.isShowingPINSetup) {
            PINSetupView(store: store)
            #if os(iOS)
                .presentationDetents([.height(300)])
            #endif
        }
        .sheet(isPresented: $isShowingSpeedTest) {
            StreamSpeedTestView()
            #if os(iOS)
                .presentationDetents([.medium, .large])
            #endif
        }
        .sheet(isPresented: Binding(
            get: { store.isTraktAuthSheetPresented },
            set: { store.send(.setTraktAuthSheetPresented($0)) }
        )) {
            TraktAuthView(
                store: store.scope(state: \.traktState, action: \.traktAction),
                onClose: {
                    store.send(.setTraktAuthSheetPresented(false))
                }
            )
        }
        .sheet(isPresented: Binding(
            get: { store.isShowingHiddenContentSheet },
            set: { _ in store.send(.closeHiddenContentManagement) }
        )) {
            HiddenContentManagementView(store: store)
        }
        .sheet(isPresented: Binding(
            get: { store.isCustomEPGSheetPresented },
            set: { store.send(.setCustomEPGSheetPresented($0)) }
        )) {
            CustomEPGSettingsView(store: store)
        }
        .sheet(isPresented: $isShowingTraktWatchlist) {
            NavigationStack {
                TraktWatchlistView(store: store.scope(state: \.traktState, action: \.traktAction))
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(AppStrings.Common.close) {
                                isShowingTraktWatchlist = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: Binding(
            get: { diagnosticReportURL != nil },
            set: {
                if !$0 {
                    removeDiagnosticReport()
                }
            }
        ), onDismiss: removeDiagnosticReport) {
            if let diagnosticReportURL {
                DiagnosticReportPreviewView(url: diagnosticReportURL)
            }
        }
        .alert(
            "PureIPTV Bildirimi",
            isPresented: $isShowingBackupAlert
        ) {
            Button(AppStrings.Common.ok, role: .cancel) {}
        } message: {
            Text(backupAlertMessage ?? "")
        }
    }

    private func removeDiagnosticReport() {
        if let diagnosticReportURL {
            try? FileManager.default.removeItem(at: diagnosticReportURL)
        }
        diagnosticReportURL = nil
    }
}

private struct DiagnosticReportPreviewView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    private var reportText: String {
        (try? String(contentsOf: url, encoding: .utf8)) ?? AppStrings.Settings.diagnosticReportUnavailable
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(reportText)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                #if os(iOS)
                    .textSelection(.enabled)
                #endif
                    .padding()
            }
            .navigationTitle(AppStrings.Settings.diagnosticReportTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppStrings.Common.close) { dismiss() }
                        .accessibilityLabel(AppStrings.Common.close)
                }
                #if os(iOS)
                    ToolbarItem(placement: .confirmationAction) {
                        ShareLink(
                            item: DiagnosticReportFile(url: url),
                            preview: SharePreview(
                                AppStrings.Settings.diagnosticReportTitle,
                                image: Image(systemName: "doc.text")
                            )
                        ) {
                            Label(AppStrings.Settings.shareDiagnosticReport, systemImage: "square.and.arrow.up")
                        }
                        .accessibilityLabel(AppStrings.Settings.shareDiagnosticReport)
                    }
                #endif
            }
        }
    }
}

#if os(iOS)
    private struct DiagnosticReportFile: Transferable {
        let url: URL

        static var transferRepresentation: some TransferRepresentation {
            FileRepresentation(exportedContentType: .plainText) { report in
                SentTransferredFile(report.url)
            }
        }
    }
#endif

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
