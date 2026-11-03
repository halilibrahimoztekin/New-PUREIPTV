import ComposableArchitecture
import SwiftUI

public struct PlaylistManagementView: View {
    @Bindable var store: StoreOf<PlaylistManagementFeature>
    @State private var hasDisappeared = false

    public init(store: StoreOf<PlaylistManagementFeature>) {
        self.store = store
    }

    public var body: some View {
        List {
            // Section: Saved Playlists
            Section {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: store.playlistStoreStatus == .unavailable ? "exclamationmark.icloud" : "icloud")
                        .foregroundStyle(store.playlistStoreStatus == .unavailable ? Color.orange : Color.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(playlistStoreStatusTitle)
                            .font(.subheadline)
                        Text(playlistStoreStatusDetail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                    Button("Yenile") { store.send(.refreshPlaylistStore) }
                        .font(.footnote)
                        .disabled(store.isUpdatingSources)
                }
                .padding(.vertical, 4)

                ForEach(store.playlists) { playlist in
                    playlistRow(playlist)
                    #if os(iOS)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                store.send(.playlistLockTapped(playlist.id))
                            } label: {
                                Label(
                                    store.lockedPlaylistIDs.contains(playlist.id) ? "PIN Kilidini Kaldır" : "PIN Kilidi Ayarla",
                                    systemImage: store.lockedPlaylistIDs.contains(playlist.id) ? "lock.open" : "lock"
                                )
                            }
                            Button {
                                store.send(.editPlaylistSettings(playlist))
                            } label: {
                                Label(AppStrings.PlaylistMgmt.playbackSettings, systemImage: "slider.horizontal.3")
                            }
                            Button(role: .destructive) {
                                store.send(.confirmDeletePlaylist(playlist))
                            } label: {
                                Label(AppStrings.Common.delete, systemImage: "trash")
                            }
                        }
                    #endif
                }
            } header: {
                Text(AppStrings.PlaylistMgmt.savedAccounts)
            } footer: {
                Text(AppStrings.PlaylistMgmt.switchNote)
            }

            if store.startupUnlockPlaylistID == nil,
               store.playlistStoreStatus == .available,
               store.assignableContentPlaylists.count > 1
            {
                Section {
                    contentSourcePicker(AppStrings.PlaylistMgmt.liveTVRefreshFrequency, area: .liveTV)
                    contentSourcePicker(AppStrings.PlaylistMgmt.moviesRefreshFrequency, area: .movies)
                    contentSourcePicker(AppStrings.PlaylistMgmt.seriesRefreshFrequency, area: .series)
                } header: {
                    Text(AppStrings.PlaylistMgmt.contentSources)
                } footer: {
                    Text(AppStrings.PlaylistMgmt.contentSourcesDescription)
                }
            }

            if store.startupUnlockPlaylistID == nil, hasUpdateableSources {
                Section {
                    Button {
                        store.send(.updateAllSources)
                    } label: {
                        HStack {
                            Label(AppStrings.PlaylistMgmt.updateAllSources, systemImage: "arrow.clockwise")
                            Spacer()
                            if store.isUpdatingSources {
                                ProgressView()
                                    .accessibilityLabel(AppStrings.Common.loading)
                            }
                        }
                    }
                    .disabled(store.isUpdatingSources)
                    .accessibilityHint(store.isUpdatingSources ? AppStrings.Common.loading : AppStrings.PlaylistMgmt.refreshSource)

                    if store.isUpdatingSources {
                        Button(AppStrings.Common.cancel) {
                            store.send(.cancelSourceUpdates)
                        }
                    }

                    ForEach(store.updateSources) { source in
                        Button {
                            store.send(.updateSourceTapped(source.id))
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: updateSourceSymbol(source.kind))
                                    .foregroundStyle(AppColors.primary)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(source.title)
                                        .foregroundStyle(AppColors.textPrimary)
                                    Text(updateSourceKindTitle(source.kind))
                                        .font(AppFonts.footnote)
                                        .foregroundStyle(AppColors.textSecondary)
                                    if case let .updating(stage) = source.status {
                                        Text(stage)
                                            .font(AppFonts.caption)
                                            .foregroundStyle(AppColors.textSecondary)
                                            .lineLimit(1)
                                    } else if case .failed = source.status {
                                        Text(AppStrings.PlaylistMgmt.updateFailed)
                                            .font(AppFonts.caption)
                                            .foregroundStyle(AppColors.error)
                                            .fixedSize(horizontal: false, vertical: true)
                                    } else if case .unavailable = source.status {
                                        Text(AppStrings.PlaylistMgmt.healthNotConfigured)
                                            .font(AppFonts.caption)
                                            .foregroundStyle(AppColors.textSecondary)
                                    }
                                }
                                Spacer(minLength: 8)
                                updateSourceStatusView(source.status)
                            }
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .disabled(isUpdateSourceDisabled(source))
                        .accessibilityLabel(
                            "\(source.title), \(updateSourceKindTitle(source.kind)), \(updateSourceStatusTitle(source.status))"
                        )
                        .accessibilityHint(store.isUpdatingSources ? AppStrings.Common.loading : AppStrings.PlaylistMgmt.refreshSource)
                        #if os(tvOS)
                            .buttonStyle(TVCategoryRowButtonStyle(accentColor: AppColors.primary, isSelected: false))
                        #else
                            .buttonStyle(.plain)
                        #endif
                    }
                } header: {
                    Text(AppStrings.PlaylistMgmt.updateCenter)
                }
            }

            if store.startupUnlockPlaylistID == nil {
                // Section: Add Account Button
                Section {
                    Button {
                        store.send(.addPlaylistButtonTapped)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(AppFonts.titleLarge)
                                .foregroundStyle(AppColors.primary)
                            Text(AppStrings.PlaylistMgmt.addAccount)
                                .font(AppFonts.headline)
                                .foregroundStyle(AppColors.primary)
                            Spacer()
                        }
                        .padding(.vertical, 6)
                    }
                    .disabled(store.isUpdatingSources)
                    #if os(tvOS)
                        .buttonStyle(TVCategoryRowButtonStyle(accentColor: AppColors.primary, isSelected: false))
                    #else
                        .buttonStyle(.plain)
                    #endif
                }
            }
        }
        .navigationTitle(AppStrings.PlaylistMgmt.accountManagement)
        #if os(iOS)
            .navigationBarBackButtonHidden(true)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if store.startupUnlockPlaylistID == nil {
                        Button {
                            #if os(iOS)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
                            store.send(.closeTapped)
                        } label: {
                            #if os(tvOS)
                                Text(AppStrings.Common.cancel)
                            #else
                                Image(systemName: "chevron.left")
                                    .font(AppFonts.headline)
                                    .foregroundColor(AppColors.textPrimary)
                                    .padding(8)
                                    .background(.ultraThinMaterial, in: Circle())
                            #endif
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    if store.startupUnlockPlaylistID == nil {
                        Button {
                            store.send(.addPlaylistButtonTapped)
                        } label: {
                            Image(systemName: "plus")
                        }
                        .disabled(store.isUpdatingSources)
                    }
                }
            }
            .onAppear {
                hasDisappeared = false
                store.send(.onAppear)
            }
            .onDisappear {
                guard !hasDisappeared else { return }
                hasDisappeared = true
                store.send(.viewDidDisappear)
            }
        #if os(tvOS)
            .onExitCommand {
                store.send(.closeTapped)
            }
        #endif
    }

    private var playlistStoreStatusTitle: String {
        switch store.playlistStoreStatus {
        case .available: "Bu cihazdaki Keychain kaydı okunabildi"
        case .empty: "Bu cihazda kayıtlı playlist yok"
        case .unavailable: "Keychain kaydı okunamadı"
        }
    }

    private var playlistStoreStatusDetail: String {
        #if os(tvOS)
            "tvOS, iCloud Keychain öğelerini cihazlar arasında eşitlemez."
        #else
            switch store.playlistStoreStatus {
            case .available, .empty:
                "iCloud Keychain eşitlemesi Apple tarafından yönetilir; diğer cihaza ulaşma durumu veya süresi bu uygulamaya bildirilmez."
            case .unavailable:
                "iCloud Keychain erişimini kontrol edip Yenile'ye dokunun. Parolalar gösterilmez."
            }
        #endif
    }

    private func updateSourceKindTitle(_ kind: PlaylistManagementFeature.State.UpdateSourceKind) -> String {
        switch kind {
        case .playlistCatalog: AppStrings.PlaylistMgmt.updateCatalog
        case .providerEPG: AppStrings.PlaylistMgmt.updateProviderEPG
        case .customEPG: AppStrings.PlaylistMgmt.updateCustomEPG
        }
    }

    private func updateSourceSymbol(_ kind: PlaylistManagementFeature.State.UpdateSourceKind) -> String {
        switch kind {
        case .playlistCatalog: "square.stack.3d.up"
        case .providerEPG: "calendar"
        case .customEPG: "calendar.badge.clock"
        }
    }

    @ViewBuilder
    private func updateSourceStatusView(_ status: PlaylistManagementFeature.State.UpdateSourceStatus) -> some View {
        switch status {
        case .ready:
            Image(systemName: "arrow.clockwise")
                .foregroundStyle(Color.secondary)
                .accessibilityLabel(AppStrings.PlaylistMgmt.refreshSource)
        case .queued:
            Image(systemName: "clock")
                .foregroundStyle(Color.secondary)
                .accessibilityLabel(AppStrings.Common.loading)
        case .updating:
            ProgressView()
                .accessibilityLabel(AppStrings.Common.loading)
        case .succeeded:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.green)
                .accessibilityLabel(AppStrings.Common.done)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.red)
                .accessibilityLabel(AppStrings.PlaylistMgmt.updateFailed)
        case .unavailable:
            Image(systemName: "minus.circle")
                .foregroundStyle(Color.secondary)
                .accessibilityLabel(AppStrings.PlaylistMgmt.healthNotConfigured)
        }
    }

    private func isUnavailable(_ status: PlaylistManagementFeature.State.UpdateSourceStatus) -> Bool {
        if case .unavailable = status {
            return true
        }
        return false
    }

    private var hasUpdateableSources: Bool {
        store.updateSources.contains { source in
            if case .customEPG = source.kind {
                return true
            }
            return store.playlistStoreStatus == .available
        }
    }

    private func isUpdateSourceDisabled(_ source: PlaylistManagementFeature.State.UpdateSource) -> Bool {
        guard !isUnavailable(source.status) else { return true }
        if case .customEPG = source.kind {
            return false
        }
        return store.playlistStoreStatus != .available
    }

    private func updateSourceStatusTitle(_ status: PlaylistManagementFeature.State.UpdateSourceStatus) -> String {
        switch status {
        case .ready: AppStrings.PlaylistMgmt.refreshSource
        case .queued, .updating: AppStrings.Common.loading
        case .succeeded: AppStrings.Common.done
        case .failed: AppStrings.PlaylistMgmt.updateFailed
        case .unavailable: AppStrings.PlaylistMgmt.healthNotConfigured
        }
    }

    // MARK: - Playlist Row

    @ViewBuilder
    private func playlistRow(_ playlist: SavedPlaylist) -> some View {
        let isActive = store.activePlaylistID == playlist.id

        HStack(spacing: 8) {
            Button {
                store.send(.setActivePlaylist(playlist.id))
            } label: {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isActive ? AppColors.primary.opacity(0.2) : AppColors.glassPlate)
                            .frame(width: 44, height: 44)

                        Image(systemName: playlist.type == .xtream ? "server.rack" : "doc.text")
                            .font(AppFonts.titleMedium)
                            .foregroundStyle(isActive ? AppColors.primary : AppColors.textSecondary)
                            .accessibilityHidden(true)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(playlist.name)
                                .font(AppFonts.headline)
                                .foregroundStyle(AppColors.textPrimary)

                            if isActive {
                                Text("Aktif")
                                    .font(AppFonts.captionBold)
                                    .foregroundStyle(AppColors.textPrimary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(AppColors.success))
                            }
                        }

                        Text(displayAddress(for: playlist))
                            .font(AppFonts.caption)
                            .foregroundStyle(AppColors.onSurfaceVariant.opacity(0.6))
                            .lineLimit(1)
                    }

                    if store.lockedPlaylistIDs.contains(playlist.id) {
                        Image(systemName: "lock.fill")
                            .font(AppFonts.headline)
                            .foregroundStyle(AppColors.warning)
                            .accessibilityLabel("PIN ile kilitli")
                    }

                    Spacer(minLength: 0)

                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .font(AppFonts.titleLarge)
                            .foregroundStyle(AppColors.success)
                            .accessibilityLabel("Aktif playlist")
                    }
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            #if os(tvOS)
            .buttonStyle(TVCategoryRowButtonStyle(accentColor: AppColors.primary, isSelected: isActive))
            #else
            .buttonStyle(.plain)
            #endif
            .opacity(store.isUpdatingSources ? 0.65 : 1)
            .accessibilityValue(store.isUpdatingSources ? AppStrings.Common.loading : "")

            #if os(tvOS)
                Button {
                    store.send(.editPlaylistSettings(playlist))
                } label: {
                    Image(systemName: "text.badge.checkmark")
                        .font(AppFonts.titleMedium)
                        .foregroundStyle(AppColors.primary)
                        .padding(8)
                }
                .buttonStyle(TVCircleButtonStyle())
                .accessibilityLabel(AppStrings.PlaylistMgmt.playbackSettings)
                .opacity(store.isUpdatingSources ? 0.65 : 1)
                .accessibilityValue(store.isUpdatingSources ? AppStrings.Common.loading : "")

                Button {
                    store.send(.confirmDeletePlaylist(playlist))
                } label: {
                    Image(systemName: "trash")
                        .font(AppFonts.titleMedium)
                        .foregroundStyle(AppColors.error.opacity(0.8))
                        .padding(8)
                }
                .buttonStyle(TVCircleButtonStyle())
                .accessibilityLabel(AppStrings.Common.delete)
                .opacity(store.isUpdatingSources ? 0.65 : 1)
                .accessibilityValue(store.isUpdatingSources ? AppStrings.Common.loading : "")
            #endif
        }
        .contextMenu {
            Button {
                store.send(.playlistLockTapped(playlist.id))
            } label: {
                Label(
                    store.lockedPlaylistIDs.contains(playlist.id) ? "PIN Kilidini Kaldır" : "PIN Kilidi Ayarla",
                    systemImage: store.lockedPlaylistIDs.contains(playlist.id) ? "lock.open" : "lock"
                )
            }
            .disabled(store.isUpdatingSources)
        }
    }

    private var channelZappingDelayValue: String {
        guard store.channelZappingDelayDraft > 0 else { return AppStrings.Player.off }
        return AppStrings.PlaylistMgmt.channelZappingDelayValue(store.channelZappingDelayDraft)
    }

    private func displayAddress(for playlist: SavedPlaylist) -> String {
        guard let rawAddress = playlist.serverURL ?? playlist.m3uURL,
              let components = URLComponents(string: rawAddress),
              let host = components.host,
              let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme)
        else {
            return AppStrings.Errors.invalidURL
        }
        let port = components.port.map { ":\($0)" } ?? ""
        return "\(scheme)://\(host)\(port)"
    }

    private func contentSourcePicker(_ title: String, area: PlaylistContentArea) -> some View {
        Picker(title, selection: Binding(
            get: {
                guard let playlistID = store.contentSourceSelection.playlistID(for: area),
                      store.assignableContentPlaylists.contains(where: { $0.id == playlistID })
                else { return nil }
                return playlistID
            },
            set: { store.send(.setContentSource(area: area, playlistID: $0)) }
        )) {
            Text(AppStrings.PlaylistMgmt.activePlaylistSource)
                .tag(UUID?.none)
            ForEach(store.assignableContentPlaylists) { playlist in
                Text(playlist.name)
                    .tag(Optional(playlist.id))
            }
        }
        .disabled(store.isUpdatingSources)
    }

    func playlistSettingsForm(for playlist: SavedPlaylist) -> some View {
        Form {
            Section(playlist.name) {
                Toggle(
                    isOn: Binding(
                        get: { store.defaultStartupPlaylistID == playlist.id },
                        set: { isEnabled in
                            store.send(.setDefaultStartupPlaylist(isEnabled ? playlist.id : nil))
                        }
                    )
                ) {
                    Text(AppStrings.PlaylistMgmt.defaultStartupPlaylist)
                }
                .accessibilityHint(AppStrings.PlaylistMgmt.defaultStartupPlaylistDescription)

                Toggle(AppStrings.PlaylistMgmt.automaticCatalogRefresh, isOn: $store.automaticCatalogRefreshEnabledDraft)
                Text(AppStrings.PlaylistMgmt.automaticCatalogRefreshDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text(AppStrings.PlaylistMgmt.refreshScheduleTitle)
                    .font(.headline)
                if playlist.type == .xtream || playlist.type == .m3u {
                    Picker(PlaylistRefreshTarget.live.title, selection: $store.refreshScheduleDraft.live) {
                        ForEach(PlaylistRefreshInterval.allCases) { interval in
                            Text(interval.title).tag(interval)
                        }
                    }
                }
                Picker(PlaylistRefreshTarget.movies.title, selection: $store.refreshScheduleDraft.movies) {
                    ForEach(PlaylistRefreshInterval.allCases) { interval in
                        Text(interval.title).tag(interval)
                    }
                }
                Picker(PlaylistRefreshTarget.series.title, selection: $store.refreshScheduleDraft.series) {
                    ForEach(PlaylistRefreshInterval.allCases) { interval in
                        Text(interval.title).tag(interval)
                    }
                }
                if playlist.type == .xtream || playlist.type == .m3u {
                    Picker(PlaylistRefreshTarget.epg.title, selection: $store.refreshScheduleDraft.epg) {
                        ForEach(PlaylistRefreshInterval.allCases) { interval in
                            Text(interval.title).tag(interval)
                        }
                    }
                }
                Text(AppStrings.PlaylistMgmt.refreshScheduleDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if playlist.type == .xtream {
                    TextField("Server URL", text: $store.serverURLDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    TextField("Username", text: $store.usernameDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $store.passwordDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else if playlist.type == .m3u {
                    TextField("M3U URL", text: $store.m3uURLDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                } else {
                    TextField("Server URL", text: $store.serverURLDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    Text("Plex/Emby bağlantısı kaydedilmeden önce mevcut kimlik bilgileriyle doğrulanır.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if playlist.type == .emby {
                        Picker(AppStrings.PlaylistMgmt.embyPlaybackPreference, selection: $store.mediaServerPlaybackPreferenceDraft) {
                            ForEach(MediaServerPlaybackPreference.allCases) { preference in
                                Text(preference == .automatic
                                    ? AppStrings.PlaylistMgmt.embyPlaybackAutomatic
                                    : AppStrings.PlaylistMgmt.embyPlaybackDirectStreamOnly)
                                    .tag(preference)
                            }
                        }
                        #if os(tvOS)
                        .pickerStyle(.menu)
                        #endif
                        .accessibilityHint(AppStrings.PlaylistMgmt.embyPlaybackDirectStreamOnlyDescription)
                        Text(AppStrings.PlaylistMgmt.embyPlaybackDirectStreamOnlyDescription)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                TextField("User-Agent", text: $store.userAgentDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityLabel("\(playlist.name) için özel User-Agent")
                Text("Boş bırakılırsa uygulamanın genel User-Agent değeri kullanılır.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 8) {
                    #if os(tvOS)
                        Picker(AppStrings.PlaylistMgmt.channelZappingDelay, selection: $store.channelZappingDelayDraft) {
                            ForEach(Array(stride(from: 0, through: 3000, by: 250)), id: \.self) { delay in
                                Text(delay == 0 ? AppStrings.Player.off : AppStrings.PlaylistMgmt.channelZappingDelayValue(delay))
                                    .tag(delay)
                            }
                        }
                        .pickerStyle(.menu)
                    #else
                        Stepper(value: $store.channelZappingDelayDraft, in: 0 ... 3000, step: 250) {
                            HStack {
                                Text(AppStrings.PlaylistMgmt.channelZappingDelay)
                                Spacer()
                                Text(channelZappingDelayValue)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    #endif
                    Text(AppStrings.PlaylistMgmt.channelZappingDelayDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let message = store.playlistValidationMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                if store.isRefreshingPlaylist {
                    ProgressView("Playlist doğrulanıyor…")
                        .font(.footnote)
                }
            }

            Section {
                Toggle(
                    AppStrings.PlaylistMgmt.playlistICloudSync,
                    isOn: Binding(
                        get: { store.playlistCloudSyncEnabledDraft },
                        set: { store.send(.setPlaylistCloudSyncEnabled(playlist.id, $0)) }
                    )
                )
                Text(AppStrings.PlaylistMgmt.playlistICloudSyncDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text(AppStrings.Settings.cloudSyncSection)
            }

            Section {
                Button {
                    store.send(.checkPlaylistHealth)
                } label: {
                    Label(AppStrings.PlaylistMgmt.healthCheck, systemImage: "waveform.path.ecg")
                }
                .disabled(store.isCheckingPlaylistHealth || store.isRefreshingPlaylist)
                .accessibilityHint(AppStrings.PlaylistMgmt.healthCheckDescription)

                if store.isCheckingPlaylistHealth {
                    ProgressView(AppStrings.PlaylistMgmt.healthCheckProgress)
                        .accessibilityLabel(AppStrings.PlaylistMgmt.healthCheckProgress)
                }
            } header: {
                Text(AppStrings.PlaylistMgmt.healthReportTitle)
            } footer: {
                Text(AppStrings.PlaylistMgmt.healthCheckDescription)
            }

            if let report = store.playlistHealthReport {
                Section {
                    ForEach(report.checks) { check in
                        let title = healthCheckTitle(check.kind)
                        let statusTitle = healthStatusTitle(check.status)
                        let detail = healthStatusDetail(check.status)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 10) {
                                Image(systemName: healthStatusSymbol(check.status))
                                    .foregroundStyle(healthStatusColor(check.status))
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(title)
                                        .font(.body.weight(.medium))
                                    Text(statusTitle)
                                        .font(.subheadline)
                                        .foregroundStyle(healthStatusColor(check.status))
                                }
                                Spacer(minLength: 8)
                            }
                            if let detail {
                                Text(detail)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.vertical, 3)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(title). \(statusTitle). \(detail ?? "")")
                    }
                    Text(report.checkedAt, style: .time)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text(AppStrings.PlaylistMgmt.healthReportTitle)
                }
            }
        }
    }

    private func healthCheckTitle(_ kind: PlaylistHealthCheckKind) -> String {
        switch kind {
        case .connection: AppStrings.PlaylistMgmt.healthConnection
        case .authentication: AppStrings.PlaylistMgmt.healthAuthentication
        case .format: AppStrings.PlaylistMgmt.healthFormat
        case .parsing: AppStrings.PlaylistMgmt.healthParsing
        case .epg: AppStrings.PlaylistMgmt.healthEPG
        }
    }

    private func healthStatusTitle(_ status: PlaylistHealthStatus) -> String {
        switch status {
        case .passed: AppStrings.PlaylistMgmt.healthPassed
        case .failed: AppStrings.PlaylistMgmt.healthFailed
        case .notChecked: AppStrings.PlaylistMgmt.healthNotChecked
        case .notConfigured: AppStrings.PlaylistMgmt.healthNotConfigured
        case .notApplicable: AppStrings.PlaylistMgmt.healthNotApplicable
        }
    }

    private func healthStatusDetail(_ status: PlaylistHealthStatus) -> String? {
        switch status {
        case let .failed(issue), let .notChecked(issue):
            AppStrings.PlaylistMgmt.healthIssueDescription(issue)
        case .passed, .notConfigured, .notApplicable:
            nil
        }
    }

    private func healthStatusSymbol(_ status: PlaylistHealthStatus) -> String {
        switch status {
        case .passed: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .notChecked, .notConfigured, .notApplicable: "minus.circle"
        }
    }

    private func healthStatusColor(_ status: PlaylistHealthStatus) -> Color {
        switch status {
        case .passed: .green
        case .failed: .red
        case .notChecked, .notConfigured, .notApplicable: .secondary
        }
    }
}

struct PlaylistManagementPINPromptView: View {
    @Bindable var store: StoreOf<PlaylistManagementFeature>
    let isStartupUnlock: Bool
    let onCancel: () -> Void
    @FocusState private var isPINFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("4 haneli PIN", text: Binding(
                        get: { store.playlistPIN },
                        set: { store.send(.playlistPINChanged($0)) }
                    ))
                    .focused($isPINFocused)
                    #if os(iOS)
                        .keyboardType(.numberPad)
                    #endif
                        .accessibilityLabel("Playlist PIN")
                    if isConfiguringPIN {
                        SecureField("PIN'i tekrar girin", text: Binding(
                            get: { store.playlistPINConfirmation },
                            set: { store.send(.playlistPINConfirmationChanged($0)) }
                        ))
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .accessibilityLabel("PIN doğrulaması")
                    }
                    if let error = store.playlistPINError {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                } footer: {
                    Text("PIN bu playlist için ayrı saklanır ve iCloud Keychain ile eşitlenebilir.")
                }
            }
            .navigationTitle(playlistPINTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !isStartupUnlock {
                        Button(AppStrings.Common.cancel, action: onCancel)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(playlistPINActionTitle) {
                        guard store.playlistPIN.count == 4,
                              !isConfiguringPIN || store.playlistPINConfirmation.count == 4
                        else { return }
                        store.send(.submitPlaylistPIN)
                    }
                }
            }
            .onAppear {
                isPINFocused = true
            }
        }
    }

    private var isConfiguringPIN: Bool {
        if case .configure? = store.pinFlow {
            return true
        }
        return false
    }

    private var playlistPINTitle: String {
        switch store.pinFlow {
        case .configure?: "PIN Kilidi Ayarla"
        case .activate?: "Playlist Kilidini Aç"
        case .remove?: "Kilidi Kaldırmak için PIN"
        case .startup?: "Başlamak için PIN"
        case nil: "Playlist PIN"
        }
    }

    private var playlistPINActionTitle: String {
        if isConfiguringPIN {
            return "Kilitle"
        }
        if case .remove? = store.pinFlow {
            return "Kilidi Kaldır"
        }
        return "Devam Et"
    }
}
