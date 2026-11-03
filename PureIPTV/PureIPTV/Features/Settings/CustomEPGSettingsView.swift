import ComposableArchitecture
import SwiftUI

// MARK: - Custom EPG Settings View (Madde #23)

/// Obsidian glassmorphic settings view for managing external XMLTV / GZ sources,
/// per-channel EPG mappings, and time-shift offsets (+/- 12 hours).
public struct CustomEPGSettingsView: View {
    @Bindable var store: StoreOf<SettingsFeature>
    @Environment(\.dismiss) private var dismiss
    private let onClose: (() -> Void)?
    @State private var epgMappingSearchText = ""

    private var visibleEPGMappingSuggestions: [EPGMappingSuggestion] {
        let query = epgMappingSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.epgMappingSuggestions }
        return store.epgMappingSuggestions.filter { suggestion in
            suggestion.channelName.localizedCaseInsensitiveContains(query)
                || suggestion.candidates.contains { candidate in
                    candidate.option.channelName.localizedCaseInsensitiveContains(query)
                        || candidate.option.sourceName.localizedCaseInsensitiveContains(query)
                }
        }
    }

    private var retryableCustomEPGFailureCount: Int {
        store.customEPGSources.filter { $0.isEnabled && store.customEPGSourceErrors[$0.id] != nil }.count
    }

    private var visibleChannelEPGMappings: [ChannelEPGMapping] {
        store.channelEPGMappings.values.filter { mapping in
            mapping.playlistID == nil || mapping.playlistID == store.customEPGPlaylistID
        }
    }

    public init(store: StoreOf<SettingsFeature>, onClose: (() -> Void)? = nil) {
        self.store = store
        self.onClose = onClose
    }

    public var body: some View {
        NavigationStack {
            List {
                // Section 1: Global Time-Shift Offset
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Genel EPG Zaman Kaydırma")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("Yayın rehberi saat dilimi uyumsuzluğunu düzeltmek için tüm programları kaydırır.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        HStack(spacing: 12) {
                            Button {
                                store.send(.setGlobalEPGTimeShift(max(-12, store.epgTimeShift - 1)))
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(AppColors.primary)
                            }
                            #if !os(tvOS)
                            .buttonStyle(.plain)
                            #endif

                            Text(timeShiftText(store.epgTimeShift))
                                .font(AppFonts.bodyMedium.monospacedDigit().weight(.bold))
                                .foregroundStyle(AppColors.textPrimary)
                                .frame(minWidth: 70)

                            Button {
                                store.send(.setGlobalEPGTimeShift(min(12, store.epgTimeShift + 1)))
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(AppColors.primary)
                            }
                            #if !os(tvOS)
                            .buttonStyle(.plain)
                            #endif
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Genel Zaman Ayarı")
                }

                // Section 2: External XMLTV / GZ Sources
                Section {
                    if store.customEPGSources.isEmpty {
                        VStack(alignment: .center, spacing: 8) {
                            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                                .font(.system(size: 32))
                                .foregroundStyle(.secondary)
                            Text("Henüz harici XMLTV kaynağı eklenmedi.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Sağlayıcınızın EPG'si yetersizse internetten harici bir .xml veya .xml.gz linki ekleyebilirsiniz.")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.4))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    } else {
                        ForEach(store.customEPGSources) { source in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(source.name)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(.white)
                                        Text(source.url.absoluteString)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    Toggle("", isOn: Binding(
                                        get: { source.isEnabled },
                                        set: {
                                            guard !store.isCustomEPGLoading else { return }
                                            store.send(.toggleCustomEPGSource(id: source.id, enabled: $0))
                                        }
                                    ))
                                    .labelsHidden()
                                    #if !os(tvOS)
                                        .disabled(store.isCustomEPGLoading)
                                    #endif
                                }

                                HStack(spacing: 12) {
                                    Label("\(source.channelCount) Kanal", systemImage: "tv")
                                        .font(.caption2)
                                        .foregroundStyle(AppColors.primary)

                                    Label("\(source.programmeCount) Program", systemImage: "calendar")
                                        .font(.caption2)
                                        .foregroundStyle(AppColors.success)

                                    if let last = source.lastFetched {
                                        Text(last, style: .time)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Button {
                                        guard !store.isCustomEPGLoading else { return }
                                        store.send(.refreshCustomEPGSource(source.id))
                                    } label: {
                                        if store.customEPGRefreshingSourceID == source.id {
                                            ProgressView()
                                                .controlSize(.small)
                                        } else {
                                            Image(systemName: "arrow.clockwise")
                                                .font(.caption)
                                        }
                                    }
                                    #if !os(tvOS)
                                    .buttonStyle(.bordered)
                                    .disabled(store.isCustomEPGLoading)
                                    #endif
                                    .accessibilityLabel(AppStrings.PlaylistMgmt.refreshSource)
                                    .accessibilityValue(
                                        store.customEPGRefreshingSourceID == source.id ? AppStrings.Common.loading : ""
                                    )
                                }

                                if let error = store.customEPGSourceErrors[source.id] {
                                    Label(error, systemImage: "exclamationmark.triangle.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.red)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let id = store.customEPGSources[index].id
                                store.send(.removeCustomEPGSource(id))
                            }
                        }
                    }

                    Button {
                        store.send(.setAddCustomEPGSourceSheetPresented(true))
                    } label: {
                        Label("Yeni XMLTV / GZ Kaynağı Ekle", systemImage: "plus.circle")
                            .font(AppFonts.headline)
                            .foregroundStyle(AppColors.primary)
                    }

                    if !store.customEPGSources.isEmpty {
                        Button {
                            guard !store.isCustomEPGLoading else { return }
                            store.send(.refreshAllCustomEPGSources)
                        } label: {
                            HStack {
                                Label("Tüm Kaynakları Güncelle", systemImage: "arrow.triangle.2.circlepath")
                                if store.isCustomEPGLoading {
                                    Spacer()
                                    ProgressView()
                                        .controlSize(.small)
                                }
                            }
                        }
                        #if !os(tvOS)
                        .disabled(store.isCustomEPGLoading)
                        #endif
                    }

                    if retryableCustomEPGFailureCount > 0 {
                        Button {
                            guard !store.isCustomEPGLoading else { return }
                            store.send(.retryFailedCustomEPGSources)
                        } label: {
                            HStack {
                                Label(
                                    AppStrings.Settings.retryFailedCustomEPGSources(retryableCustomEPGFailureCount),
                                    systemImage: "arrow.clockwise.circle"
                                )
                                if store.isCustomEPGLoading {
                                    Spacer()
                                    ProgressView().controlSize(.small)
                                }
                            }
                        }
                        #if !os(tvOS)
                        .disabled(store.isCustomEPGLoading)
                        #endif
                    }

                    if store.isCustomEPGLoading {
                        HStack(spacing: 10) {
                            ProgressView()
                                .controlSize(.small)
                                .accessibilityLabel(AppStrings.Common.loading)
                            if let sourceID = store.customEPGRefreshingSourceID,
                               let source = store.customEPGSources.first(where: { $0.id == sourceID })
                            {
                                Text("\(source.name) · \(store.customEPGRefreshCurrentIndex)/\(store.customEPGRefreshTotalCount)")
                                    .font(.caption)
                                    .lineLimit(1)
                            } else {
                                Text(AppStrings.Common.loadingAlt)
                                    .font(.caption)
                            }
                            Spacer(minLength: 4)
                            Button(AppStrings.Common.cancel) {
                                store.send(.cancelCustomEPGRefresh)
                            }
                        }
                        .accessibilityElement(children: .contain)
                    }
                } header: {
                    Text("Harici XMLTV / GZ Kaynakları")
                } footer: {
                    Text("Desteklenen formatlar: Doğrudan XML (.xml) ve sıkıştırılmış Gzip (.xml.gz) dosyaları.")
                }

                Section {
                    TextField(AppStrings.Search.channelSearchPlaceholder, text: $epgMappingSearchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button {
                        guard !store.isLoadingEPGMappingSuggestions,
                              store.customEPGSources.contains(where: \.isEnabled) else { return }
                        store.send(.loadEPGMappingSuggestions)
                    } label: {
                        HStack {
                            Label(AppStrings.Settings.findEPGMappingSuggestions, systemImage: "sparkles")
                            if store.isLoadingEPGMappingSuggestions {
                                Spacer()
                                ProgressView().controlSize(.small)
                            }
                        }
                    }
                    #if !os(tvOS)
                    .disabled(store.isLoadingEPGMappingSuggestions || !store.customEPGSources.contains(where: \.isEnabled))
                    #else
                    .opacity(store.customEPGSources.contains(where: \.isEnabled) ? 1 : 0.55)
                    #endif
                    .accessibilityValue(store.isLoadingEPGMappingSuggestions ? AppStrings.Common.loading : "")

                    Text(AppStrings.Settings.epgMappingSuggestionsDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(AppStrings.Settings.secondaryEPGSourcePriorityDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let message = store.epgMappingSuggestionError {
                        ContentUnavailableView(message, systemImage: "antenna.radiowaves.left.and.right.slash")
                    }

                    ForEach(visibleEPGMappingSuggestions) { suggestion in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(suggestion.channelName)
                                .font(.headline)
                            ForEach(suggestion.candidates) { candidate in
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(candidate.option.channelName)
                                            .font(.subheadline.weight(.semibold))
                                        Text("\(candidate.option.sourceName) · \(AppStrings.Settings.epgMappingConfidence(candidate.confidence))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 8)
                                    Button(AppStrings.Settings.confirmEPGMapping) {
                                        store.send(.applySuggestedEPGMapping(
                                            channelID: suggestion.channelID,
                                            channelName: suggestion.channelName,
                                            sourceID: candidate.option.sourceID,
                                            epgChannelID: candidate.option.channelID
                                        ))
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .accessibilityHint(AppStrings.Settings.epgMappingSuggestionsDescription)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                } header: {
                    Text(AppStrings.Settings.epgMappingSuggestionsTitle)
                }

                // Section 3: Channel-Specific EPG Mappings & Offsets
                if !visibleChannelEPGMappings.isEmpty {
                    Section {
                        ForEach(visibleChannelEPGMappings) { mapping in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mapping.channelName)
                                        .font(AppFonts.headline)
                                        .foregroundStyle(AppColors.textPrimary)
                                    if let epgID = mapping.customEPGChannelID {
                                        Text("Eşleşen EPG ID: \(epgID)")
                                            .font(.caption2)
                                            .foregroundStyle(AppColors.primary)
                                    }
                                    if let sourceID = mapping.customSourceID,
                                       let source = store.customEPGSources.first(where: { $0.id == sourceID })
                                    {
                                        Label(source.name, systemImage: "antenna.radiowaves.left.and.right")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Text(timeShiftText(mapping.timeShiftHours))
                                    .font(AppFonts.captionBold.monospacedDigit())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(mapping.timeShiftHours != 0 ? AppColors.primary.opacity(0.2) : AppColors.glassPlate)
                                    )
                                    .foregroundStyle(mapping.timeShiftHours != 0 ? AppColors.primary : .secondary)
                            }
                        }
                    } header: {
                        Text("Kanal Bazlı EPG Eşleştirmeleri (\(visibleChannelEPGMappings.count))")
                    }
                }
            }
            .navigationTitle("Özel EPG & Zaman Kaydırma")
            #if !os(tvOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Kapat") {
                            close()
                        }
                    }
                }
        }
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private func timeShiftText(_ hours: Int) -> String {
        if hours == 0 {
            "0 Saat"
        } else if hours > 0 {
            "+\(hours) Saat"
        } else {
            "\(hours) Saat"
        }
    }
}

public struct CustomEPGSourceEntryView: View {
    @Bindable var store: StoreOf<SettingsFeature>
    private let onClose: () -> Void

    public init(store: StoreOf<SettingsFeature>, onClose: @escaping () -> Void) {
        self.store = store
        self.onClose = onClose
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Kaynak Bilgileri")) {
                    TextField("Kaynak Adı (örn: Türkiye XMLTV)", text: Binding(
                        get: { store.newCustomEPGName },
                        set: { store.send(.setNewCustomEPGName($0)) }
                    ))

                    TextField("URL (https://.../epg.xml.gz)", text: Binding(
                        get: { store.newCustomEPGURLString },
                        set: { store.send(.setNewCustomEPGURLString($0)) }
                    ))
                    #if !os(tvOS)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    #endif
                }

                if let err = store.customEPGErrorMessage {
                    Section {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        guard !store.isCustomEPGLoading else { return }
                        store.send(.addCustomEPGSource)
                    } label: {
                        HStack {
                            Spacer()
                            if store.isCustomEPGLoading {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text("Kaydet ve Ayrıştır")
                                .bold()
                            Spacer()
                        }
                    }
                    #if !os(tvOS)
                    .disabled(store.newCustomEPGName.isEmpty || store.newCustomEPGURLString.isEmpty || store.isCustomEPGLoading)
                    #else
                    .opacity(
                        store.newCustomEPGName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || store.newCustomEPGURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? 0.55
                            : 1
                    )
                    #endif
                    .accessibilityLabel("Kaydet ve Ayrıştır")
                    .accessibilityValue(store.isCustomEPGLoading ? AppStrings.Common.loading : "")
                }
            }
            .navigationTitle("Yeni XMLTV Kaynağı")
            #if !os(tvOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(store.isCustomEPGLoading ? AppStrings.Common.cancel : "Vazgeç") {
                            if store.isCustomEPGLoading {
                                store.send(.cancelCustomEPGRefresh)
                            }
                            onClose()
                        }
                    }
                }
        }
    }
}
