import ComposableArchitecture
import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

public struct SettingsView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var accountInfoManager = AccountInfoManager.shared
    @ObservedObject private var userAgentManager = UserAgentManager.shared
    @Bindable var store: StoreOf<SettingsFeature>

    @State private var backupExportURL: URL? = nil
    @State private var isGeneratingDiagnosticReport = false
    @State private var isThemePackageImporterPresented = false
    @State private var isThemePackageMessagePresented = false
    @State private var themePackageMessage = ""
    @State private var themePackageImportProfileID: UUID?
    #if os(tvOS)
        @AppStorage("com.pureiptv.tvOSPlayerRemoteUpAction") private var playerRemoteUpAction = TVPlayerRemoteAction.defaultUpAction.rawValue
        @AppStorage("com.pureiptv.tvOSPlayerRemoteDownAction") private var playerRemoteDownAction = TVPlayerRemoteAction.defaultDownAction.rawValue
        @AppStorage("com.pureiptv.tvOSPlayerRemoteLeftAction") private var playerRemoteLeftAction = TVPlayerRemoteAction.defaultLeftAction.rawValue
        @AppStorage("com.pureiptv.tvOSPlayerRemoteRightAction") private var playerRemoteRightAction = TVPlayerRemoteAction.defaultRightAction.rawValue
        @AppStorage("com.pureiptv.tvOSHighContrastFocusFrame") private var isHighContrastFocusFrameEnabled = false
        @AppStorage(LiveTVFocusPreferenceKeys.favoriteChannelWrapAround) private var isFavoriteWrapAroundFocusEnabled = false
        @AppStorage(EPGTimelinePreferenceKeys.hideChannelsWithoutPrograms) private var hideChannelsWithoutPrograms = false
    #endif

    public init(store: StoreOf<SettingsFeature>) {
        self.store = store
    }

    #if os(tvOS)
        private var hasCustomPlayerRemoteActions: Bool {
            playerRemoteUpAction != TVPlayerRemoteAction.defaultUpAction.rawValue
                || playerRemoteDownAction != TVPlayerRemoteAction.defaultDownAction.rawValue
                || playerRemoteLeftAction != TVPlayerRemoteAction.defaultLeftAction.rawValue
                || playerRemoteRightAction != TVPlayerRemoteAction.defaultRightAction.rawValue
        }

        private func restorePlayerRemoteActions() {
            playerRemoteUpAction = TVPlayerRemoteAction.defaultUpAction.rawValue
            playerRemoteDownAction = TVPlayerRemoteAction.defaultDownAction.rawValue
            playerRemoteLeftAction = TVPlayerRemoteAction.defaultLeftAction.rawValue
            playerRemoteRightAction = TVPlayerRemoteAction.defaultRightAction.rawValue
        }
    #endif

    private var selectedPlaybackDefaults: PlaybackDefaults {
        store.playbackDefaultsByKind[store.selectedPlaybackContentKind]
            ?? .legacy(for: store.selectedPlaybackContentKind)
    }

    private func topShelfSectionTitle(_ section: TopShelfContentSection) -> String {
        switch section {
        case .continueWatching: AppStrings.Dashboard.continueWatching
        case .favoriteChannels: AppStrings.Dashboard.favoriteLiveTV
        case .recentMovies: AppStrings.Dashboard.newMovies
        }
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

                #if os(iOS)
                    Button {
                        store.send(.backupImportPickerRequested)
                    } label: {
                        HStack {
                            Image(systemName: "arrow.up.doc.fill")
                                .foregroundColor(.blue)
                            Text("Yedekten Geri Yükle (.iptvbackup)")
                        }
                    }
                    .foregroundColor(.primary)
                #endif

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

            Section(
                header: Text(AppStrings.Settings.tmdbAPIKeyTitle),
                footer: Text(AppStrings.Settings.tmdbAPIKeyDescription)
            ) {
                SecureField(
                    AppStrings.Settings.tmdbAPIKeyPlaceholder,
                    text: Binding(
                        get: { store.tmdbAPIKeyInput.stringValue },
                        set: { store.send(.tmdbAPIKeyInputChanged(RedactedText($0))) }
                    )
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .privacySensitive()
                .disabled(store.isValidatingTMDBAPIKey || store.isDeletingTMDBAPIKey)

                Button {
                    store.send(.validateAndSaveTMDBAPIKeyTapped)
                } label: {
                    HStack(spacing: 10) {
                        if store.isValidatingTMDBAPIKey {
                            ProgressView()
                            Text(AppStrings.Settings.tmdbAPIKeyValidating)
                        } else {
                            Label(AppStrings.Settings.tmdbAPIKeyValidateAndSave, systemImage: "checkmark.shield")
                        }
                    }
                    .frame(minHeight: 36, alignment: .leading)
                }
                .disabled(
                    store.tmdbAPIKeyInput.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || store.isValidatingTMDBAPIKey
                        || store.isDeletingTMDBAPIKey
                )

                if let statusMessage = store.tmdbAPIKeyStatusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(store.isTMDBAPIKeyStatusError ? Color.red : Color.secondary)
                        .accessibilityAddTraits(.updatesFrequently)
                }

                if store.hasSavedTMDBAPIKey {
                    Button(role: .destructive) {
                        store.send(.deleteTMDBAPIKeyTapped)
                    } label: {
                        HStack(spacing: 10) {
                            if store.isDeletingTMDBAPIKey {
                                ProgressView()
                            }
                            Label(AppStrings.Settings.tmdbAPIKeyDelete, systemImage: "key.slash")
                        }
                        .frame(minHeight: 36, alignment: .leading)
                    }
                    .disabled(store.isValidatingTMDBAPIKey || store.isDeletingTMDBAPIKey)
                }
            }

            Section(header: Text(AppStrings.Settings.contentManagement)) {
                Button {
                    store.send(.hiddenMediaManagementTapped)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "eye.slash")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(AppStrings.Settings.hiddenMediaManagement)
                                .foregroundStyle(.primary)
                            Text(AppStrings.Settings.hiddenMediaManagementDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }

            Section {
                NavigationLink {
                    ViewingStatisticsView(store: store)
                } label: {
                    Label(AppStrings.ViewingStatistics.title, systemImage: "chart.bar.xaxis")
                        .foregroundStyle(.primary)
                        .labelStyle(.titleAndIcon)
                        .tint(.blue)
                }
            }

            Section(
                header: Text(AppStrings.Settings.searchHistory),
                footer: Text(AppStrings.Settings.searchHistoryDescription)
            ) {
                Toggle(AppStrings.Settings.saveRecentSearches, isOn: Binding(
                    get: { store.isSearchHistorySavingEnabled },
                    set: { store.send(.setSearchHistorySavingEnabled($0)) }
                ))

                if store.isSearchHistorySavingEnabled {
                    Picker(AppStrings.Settings.searchHistoryRetention, selection: Binding(
                        get: { store.searchHistoryRetention },
                        set: { store.send(.setSearchHistoryRetention($0)) }
                    )) {
                        ForEach(SearchHistoryRetention.allCases) { retention in
                            Text(retention.title).tag(retention)
                        }
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

                #if os(iOS)
                    Button {
                        guard let profileID = store.personalizationProfileID else { return }
                        themePackageImportProfileID = profileID
                        isThemePackageImporterPresented = true
                    } label: {
                        Label(AppStrings.Settings.visualThemePackageImport, systemImage: "square.and.arrow.down")
                    }
                    .disabled(store.personalizationProfileID == nil)
                #endif

                ForEach(theme.importedPackages) { package in
                    HStack(spacing: 10) {
                        Button {
                            theme.setThemePreset(id: package.id)
                        } label: {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(package.accentColor)
                                    .frame(width: 16, height: 16)
                                    .accessibilityHidden(true)
                                Text(package.name)
                                    .lineLimit(1)
                                Spacer(minLength: 8)
                                if theme.selectedPresetID == package.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                        .accessibilityHidden(true)
                                }
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(theme.selectedPresetID == package.id ? .isSelected : [])

                        Button(role: .destructive) {
                            theme.removeImportedThemePackage(id: package.id)
                        } label: {
                            Image(systemName: "trash")
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(AppStrings.Settings.visualThemePackageRemove(package.name))
                    }
                }

                Text(AppStrings.Settings.visualThemePackageDescription)
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

                    Toggle(AppStrings.Settings.highContrastFocusFrame, isOn: $isHighContrastFocusFrameEnabled)
                    Text(AppStrings.Settings.highContrastFocusFrameDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Toggle(AppStrings.Settings.favoriteChannelWrapAroundFocus, isOn: $isFavoriteWrapAroundFocusEnabled)
                    Text(AppStrings.Settings.favoriteChannelWrapAroundFocusDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

                Text(AppStrings.Settings.categorySortFallbackDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                    Button {
                        restorePlayerRemoteActions()
                    } label: {
                        Label(AppStrings.Settings.restoreRemoteControlDirections, systemImage: "arrow.counterclockwise")
                    }
                    .disabled(!hasCustomPlayerRemoteActions)
                #endif

                Toggle(AppStrings.Settings.startMuted, isOn: Binding(
                    get: { store.startMuted },
                    set: { store.send(.setStartMuted($0)) }
                ))

                Picker("İçerik Türü", selection: Binding(
                    get: { store.selectedPlaybackContentKind },
                    set: { store.send(.selectPlaybackContentKind($0)) }
                )) {
                    ForEach(PlaybackContentKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    Text("Oynatıcı Motoru")
                    Spacer()
                    Text("VLC (Donanım Hızlandırmalı)")
                        .foregroundStyle(.secondary)
                }

                Picker("Arabellek", selection: Binding(
                    get: { selectedPlaybackDefaults.bufferChoice },
                    set: { store.send(.updatePlaybackDefaults(.bufferChoice($0))) }
                )) {
                    ForEach(PlaybackBufferChoice.allCases) { choice in
                        Text(choice.title).tag(choice)
                    }
                }
                Text("Otomatik, VOD için eski arabellek ayarını; Canlı ve Arşiv için motorun varsayılanını kullanır.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Daha büyük arabellek ilk görüntüyü geciktirir ve daha fazla bellek kullanır; kesintili bağlantılarda oynatımı daha dayanıklı kılabilir.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Deinterlace", selection: Binding(
                    get: { selectedPlaybackDefaults.deinterlaceMode },
                    set: { store.send(.updatePlaybackDefaults(.deinterlaceMode($0))) }
                )) {
                    ForEach(DeinterlaceMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

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

                Toggle(AppStrings.Settings.oledDimming, isOn: Binding(
                    get: { store.isOLEDDimmingEnabled },
                    set: { store.send(.setOLEDDimmingEnabled($0)) }
                ))

                Toggle(AppStrings.Settings.cleanChannelNames, isOn: Binding(
                    get: { store.isChannelNameCleaningEnabled },
                    set: { store.send(.setChannelNameCleaningEnabled($0)) }
                ))
            }

            Section(header: Text("Ekran & Kare Hızı Eşleme (AFR) — \(store.selectedPlaybackContentKind.title)")) {
                Toggle("\(store.selectedPlaybackContentKind.title) için Kare Hızı Eşleme", isOn: Binding(
                    get: { selectedPlaybackDefaults.isAFREnabled },
                    set: { store.send(.updatePlaybackDefaults(.isAFREnabled($0))) }
                ))

                Toggle("Dinamik Aralık Eşleme (HDR / Dolby Vision)", isOn: Binding(
                    get: { selectedPlaybackDefaults.isMatchDynamicRangeEnabled },
                    set: { store.send(.updatePlaybackDefaults(.isMatchDynamicRangeEnabled($0))) }
                ))

                Text("Bu varsayılanlar sonraki oynatımlarda uygulanır. Eşleme etkin olduğunda desteklenen içerik, oynatım başlarken kare hızı ve renk aralığına göre ekrana eşlenir.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if #available(iOS 26.0, tvOS 26.0, *) {
                    Toggle(AppStrings.Settings.forceSDROutput, isOn: Binding(
                        get: { selectedPlaybackDefaults.isForceSDROutputEnabled ?? false },
                        set: { store.send(.updatePlaybackDefaults(.isForceSDROutputEnabled($0))) }
                    ))
                    .disabled(selectedPlaybackDefaults.preferredEngine != .avPlayer)
                    Text(AppStrings.Settings.forceSDROutputDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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

                    Toggle(AppStrings.Dashboard.continueWatching, isOn: Binding(
                        get: { store.topShelfContentSelection.continueWatching },
                        set: { store.send(.setTopShelfContentSelection(.continueWatching, $0)) }
                    ))
                    Toggle(AppStrings.Dashboard.favoriteLiveTV, isOn: Binding(
                        get: { store.topShelfContentSelection.favoriteChannels },
                        set: { store.send(.setTopShelfContentSelection(.favoriteChannels, $0)) }
                    ))
                    Toggle(AppStrings.Dashboard.newMovies, isOn: Binding(
                        get: { store.topShelfContentSelection.recentMovies },
                        set: { store.send(.setTopShelfContentSelection(.recentMovies, $0)) }
                    ))

                    ForEach(Array(store.topShelfSectionOrder.enumerated()), id: \.element) { entry in
                        let index = entry.offset
                        let section = entry.element
                        HStack(spacing: 12) {
                            Text(topShelfSectionTitle(section))
                            Spacer()
                            if index > 0 {
                                Button {
                                    store.send(.moveTopShelfSection(section, direction: -1))
                                } label: {
                                    Label(AppStrings.CategoryMgmt.moveCategoryUp, systemImage: "arrow.up")
                                }
                            }
                            if index + 1 < store.topShelfSectionOrder.count {
                                Button {
                                    store.send(.moveTopShelfSection(section, direction: 1))
                                } label: {
                                    Label(AppStrings.CategoryMgmt.moveCategoryDown, systemImage: "arrow.down")
                                }
                            }
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

            Section(header: Text("\(AppStrings.Settings.audioAndSubtitleSettings) — \(store.selectedPlaybackContentKind.title)")) {
                if store.selectedPlaybackContentKind == .vod {
                    Picker(AppStrings.Settings.vodSkipInterval, selection: Binding(
                        get: { selectedPlaybackDefaults.vodSkipInterval },
                        set: { store.send(.updatePlaybackDefaults(.vodSkipInterval($0))) }
                    )) {
                        ForEach(PlaybackSkipInterval.allCases) { interval in
                            Text(interval.compactTitle).tag(interval)
                        }
                    }
                    Text(AppStrings.Settings.vodSkipIntervalDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if store.selectedPlaybackContentKind == .archive {
                    Picker(AppStrings.Settings.catchupSkipInterval, selection: Binding(
                        get: { selectedPlaybackDefaults.catchupSkipInterval },
                        set: { store.send(.updatePlaybackDefaults(.catchupSkipInterval($0))) }
                    )) {
                        ForEach(PlaybackSkipInterval.allCases) { interval in
                            Text(interval.compactTitle).tag(interval)
                        }
                    }
                    Text(AppStrings.Settings.catchupSkipIntervalDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Picker(AppStrings.Settings.defaultAudioLanguage, selection: Binding(
                    get: { selectedPlaybackDefaults.preferredAudioLanguage },
                    set: { store.send(.updatePlaybackDefaults(.preferredAudioLanguage($0))) }
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
                    get: { selectedPlaybackDefaults.preferredSubtitleLanguage },
                    set: { store.send(.updatePlaybackDefaults(.preferredSubtitleLanguage($0))) }
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

                if store.selectedPlaybackContentKind != .vod || selectedPlaybackDefaults.preferredEngine == .vlc {
                    Picker(AppStrings.Settings.subtitleTextSize, selection: Binding(
                        get: { selectedPlaybackDefaults.subtitleTextSize },
                        set: { store.send(.updatePlaybackDefaults(.subtitleTextSize($0))) }
                    )) {
                        ForEach(SubtitleTextSize.allCases) { size in
                            Text(size.title).tag(size)
                        }
                    }
                    Text(AppStrings.Settings.subtitleTextSizeDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Toggle(AppStrings.Settings.rememberTrackPreferences, isOn: Binding(
                    get: { store.rememberMediaTrackPreferences },
                    set: { store.send(.setRememberMediaTrackPreferences($0)) }
                ))
            }

            Section {
                Picker(AppStrings.Settings.subtitleAppearanceProfile, selection: Binding(
                    get: { store.subtitleAppearanceProfile },
                    set: { store.send(.setSubtitleAppearanceProfile($0)) }
                )) {
                    ForEach(SubtitleAppearanceProfile.allCases) { profile in
                        Text(profile.title).tag(profile)
                    }
                }
                Text(AppStrings.Settings.subtitleAppearanceGlobalScope)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(AppStrings.Settings.subtitleAppearanceDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(header: Text(AppStrings.Settings.epgSettings)) {
                #if os(tvOS)
                    Picker("Kanal önizlemesi", selection: Binding(
                        get: { store.epgPreviewDelay },
                        set: { store.send(.setEPGPreviewDelay($0)) }
                    )) {
                        ForEach(EPGPreviewDelay.allCases) { delay in
                            Text(delay.title).tag(delay)
                        }
                    }
                    Text("Rehberde bir kanalda bekleyince sessiz önizlemeyi başlatır. Kapalı seçeneği odak gezinirken yayın isteği göndermez; kanal menüsünden önizleme yine açılabilir.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Toggle(AppStrings.Settings.hideChannelsWithoutPrograms, isOn: $hideChannelsWithoutPrograms)
                    Text(AppStrings.Settings.hideChannelsWithoutProgramsDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                #endif

                #if os(iOS)
                    Toggle(AppStrings.Player.autoSwitchReminder, isOn: Binding(
                        get: { store.autoSwitchOnEPGReminder },
                        set: { store.send(.setAutoSwitchOnEPGReminder($0)) }
                    ))
                    Text(AppStrings.Player.autoSwitchReminderDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                #endif

                Picker(AppStrings.Settings.liveTVArtworkSource, selection: Binding(
                    get: { store.liveTVArtworkSource },
                    set: { store.send(.setLiveTVArtworkSource($0)) }
                )) {
                    ForEach(LiveTVArtworkSource.allCases) { source in
                        Text(source.title).tag(source)
                    }
                }
                Text(AppStrings.Settings.liveTVArtworkSourceDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

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

                Toggle(AppStrings.Settings.deferAutoEPGRefreshOnConstrainedNetwork, isOn: Binding(
                    get: { store.deferAutoEPGRefreshOnConstrainedNetwork },
                    set: { store.send(.setDeferAutoEPGRefreshOnConstrainedNetwork($0)) }
                ))
                .disabled(!store.autoUpdateEPG)
                Text(AppStrings.Settings.deferAutoEPGRefreshOnConstrainedNetworkDescription)
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
                            guard !store.isCloudSyncing else { return }
                            store.send(.syncNowTapped)
                        } label: {
                            HStack(spacing: 6) {
                                if store.isCloudSyncing {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                                Image(systemName: "arrow.triangle.2.circlepath.icloud.fill")
                                    .font(.caption)
                                Text("Şimdi Eşitle")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color(hex: "#0A84FF").opacity(0.15))
                            )
                            .foregroundStyle(Color(hex: "#0A84FF"))
                        }
                        .accessibilityLabel("Şimdi Eşitle")
                        .accessibilityValue(store.isCloudSyncing ? AppStrings.Player.syncing : "")
                        #if !os(tvOS)
                            .buttonStyle(.plain)
                        #endif
                        #if !os(tvOS)
                        .disabled(store.isCloudSyncing)
                        #endif
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

            Section(
                header: Text("Kişiselleştirme"),
                footer: Text("Öneriler yalnızca bu profildeki cihaz içi izleme sinyallerinden oluşturulur. Geçmişi sıfırlamak oynatma ilerlemesini ve favorileri korur.")
            ) {
                Toggle("Kişiselleştirilmiş For You önerileri", isOn: Binding(
                    get: { store.isPersonalizedRecommendationsEnabled },
                    set: { store.send(.setPersonalizedRecommendationsEnabled($0)) }
                ))

                Button(role: .destructive) {
                    store.send(.resetRecommendationHistoryTapped)
                } label: {
                    Label("Öneri geçmişini sıfırla", systemImage: "clock.arrow.circlepath")
                }
                .foregroundStyle(.red)
                .accessibilityHint("Eski izleme geçmişini For You önerilerinde kullanmayı bırakır; oynatma ilerlemesi ve favoriler korunur.")
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
                    store.send(.speedTestTapped)
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
                        store.send(.backupExportAlertPresented("Yedek dosyası başarıyla oluşturuldu:\n\(url.lastPathComponent)"))
                    } catch {
                        store.send(.backupExportAlertPresented("Yedekleme oluşturulamadı: \(error.localizedDescription)"))
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
                    guard !isGeneratingDiagnosticReport else { return }
                    isGeneratingDiagnosticReport = true
                    Task {
                        defer { isGeneratingDiagnosticReport = false }
                        if let reportURL = await FeedbackReportManager.shared.generateDiagnosticReport() {
                            store.send(.presentDiagnosticReport(reportURL))
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
                #if !os(tvOS)
                .disabled(isGeneratingDiagnosticReport)
                #endif
                .accessibilityLabel(AppStrings.Settings.createDiagnosticReport)
                .accessibilityHint(AppStrings.Settings.diagnosticReportHint)
                .accessibilityValue(isGeneratingDiagnosticReport ? AppStrings.Settings.diagnosticReportGenerating : "")
                .foregroundColor(.primary)
            }

            Section(
                header: Text(AppStrings.Settings.about),
                footer: VStack(alignment: .leading, spacing: 6) {
                    Text(AppStrings.Settings.appVersion)
                    Text(AppStrings.Settings.tmdbAttribution)
                    if let tmdbURL = URL(string: "https://www.themoviedb.org") {
                        Link("TMDB", destination: tmdbURL)
                    }
                }
            ) {
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
        .onDisappear {
            store.send(.tmdbAPIKeySettingsDisappeared)
        }
        #if os(iOS)
        .fileImporter(
            isPresented: $isThemePackageImporterPresented,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false,
            onCompletion: handleThemePackageImport
        )
        .alert(AppStrings.Settings.visualThemePreset, isPresented: $isThemePackageMessagePresented) {
            Button(AppStrings.Common.ok, role: .cancel) {}
        } message: {
            Text(themePackageMessage)
        }
        #endif
    }

    #if os(iOS)
        private func handleThemePackageImport(_ result: Result<[URL], Error>) {
            guard let profileID = themePackageImportProfileID else {
                return
            }
            themePackageImportProfileID = nil

            switch result {
            case let .success(urls):
                guard let url = urls.first, urls.count == 1 else { return }
                let hasSecurityScope = url.startAccessingSecurityScopedResource()
                defer {
                    if hasSecurityScope {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                do {
                    let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                    guard values.isRegularFile == true,
                          let fileSize = values.fileSize
                    else {
                        throw NSError(
                            domain: "PureIPTV.VisualThemePackage",
                            code: 1,
                            userInfo: [NSLocalizedDescriptionKey: AppStrings.Settings.visualThemePackageInvalid]
                        )
                    }
                    guard fileSize <= 16 * 1024 else {
                        throw NSError(
                            domain: "PureIPTV.VisualThemePackage",
                            code: 2,
                            userInfo: [NSLocalizedDescriptionKey: AppStrings.Settings.visualThemePackageTooLarge]
                        )
                    }
                    let data = try Data(contentsOf: url, options: .mappedIfSafe)
                    let package = try theme.importThemePackage(data, for: profileID)
                    themePackageMessage = AppStrings.Settings.visualThemePackageAdded(package.name)
                } catch {
                    themePackageMessage = error.localizedDescription
                }
                isThemePackageMessagePresented = true

            case let .failure(error):
                guard (error as? CocoaError)?.code != .userCancelled else { return }
                themePackageMessage = error.localizedDescription
                isThemePackageMessagePresented = true
            }
        }
    #endif
}

struct DiagnosticReportPreviewView: View {
    let url: URL
    let onClose: () -> Void
    @State private var reportText = ""
    @State private var reportChunks: [String] = []
    @State private var isLoadingReport = true

    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    if isLoadingReport {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 180)
                    } else {
                        #if os(tvOS)
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(reportChunks.indices, id: \.self) { index in
                                    Text(reportChunks[index])
                                        .font(.system(.body, design: .monospaced))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(8)
                                        .focusable()
                                        .tvFocusEffect(shape: .roundedRectangle(cornerRadius: 8))
                                }
                            }
                        #else
                            Text(reportText)
                                .font(.system(.body, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        #endif
                    }
                }
                .padding()
            }
            #if os(tvOS)
            .focusSection()
            #endif
            .navigationTitle(AppStrings.Settings.diagnosticReportTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppStrings.Common.close, action: onClose)
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
        .task(id: url) {
            isLoadingReport = true
            let reportURL = url
            let unavailableText = AppStrings.Settings.diagnosticReportUnavailable
            let worker = Task.detached(priority: .userInitiated) { () -> (String, [String])? in
                guard !Task.isCancelled else { return nil }
                let text = (try? String(contentsOf: reportURL, encoding: .utf8)) ?? unavailableText
                guard !Task.isCancelled else { return nil }
                let lines = text.components(separatedBy: .newlines)
                var chunks: [String] = []
                for start in stride(from: 0, to: lines.count, by: 5) {
                    guard !Task.isCancelled else { return nil }
                    chunks.append(lines[start ..< min(start + 5, lines.count)].joined(separator: "\n"))
                }
                return (text, chunks)
            }
            let result = await withTaskCancellationHandler {
                await worker.value
            } onCancel: {
                worker.cancel()
            }
            guard !Task.isCancelled, let result else { return }
            reportText = result.0
            reportChunks = result.1
            isLoadingReport = false
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
