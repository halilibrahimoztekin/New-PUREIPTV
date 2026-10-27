import ComposableArchitecture
import SwiftUI

// MARK: - Custom EPG Settings View (Madde #23)

/// Obsidian glassmorphic settings view for managing external XMLTV / GZ sources,
/// per-channel EPG mappings, and time-shift offsets (+/- 12 hours).
public struct CustomEPGSettingsView: View {
    @Bindable var store: StoreOf<SettingsFeature>
    @Environment(\.dismiss) private var dismiss
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

    public init(store: StoreOf<SettingsFeature>) {
        self.store = store
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
                                    .foregroundStyle(Color(hex: "#0A84FF"))
                            }
                            #if !os(tvOS)
                            .buttonStyle(.plain)
                            #endif

                            Text(timeShiftText(store.epgTimeShift))
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                                .frame(minWidth: 70)

                            Button {
                                store.send(.setGlobalEPGTimeShift(min(12, store.epgTimeShift + 1)))
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(Color(hex: "#0A84FF"))
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
                                        set: { store.send(.toggleCustomEPGSource(id: source.id, enabled: $0)) }
                                    ))
                                    .labelsHidden()
                                    .disabled(store.isCustomEPGLoading)
                                }

                                HStack(spacing: 12) {
                                    Label("\(source.channelCount) Kanal", systemImage: "tv")
                                        .font(.caption2)
                                        .foregroundStyle(Color(hex: "#0A84FF"))

                                    Label("\(source.programmeCount) Program", systemImage: "calendar")
                                        .font(.caption2)
                                        .foregroundStyle(Color(hex: "#30D158"))

                                    if let last = source.lastFetched {
                                        Text(last, style: .time)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Button {
                                        store.send(.refreshCustomEPGSource(source.id))
                                    } label: {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.caption)
                                    }
                                    #if !os(tvOS)
                                    .buttonStyle(.bordered)
                                    #endif
                                    .disabled(store.isCustomEPGLoading)
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
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color(hex: "#0A84FF"))
                    }

                    if !store.customEPGSources.isEmpty {
                        Button {
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
                        .disabled(store.isCustomEPGLoading)
                    }

                    if retryableCustomEPGFailureCount > 0 {
                        Button {
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
                        .disabled(store.isCustomEPGLoading)
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
                    .disabled(store.isLoadingEPGMappingSuggestions || !store.customEPGSources.contains(where: \.isEnabled))

                    Text(AppStrings.Settings.epgMappingSuggestionsDescription)
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
                if !store.channelEPGMappings.isEmpty {
                    Section {
                        ForEach(Array(store.channelEPGMappings.values)) { mapping in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mapping.channelName)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white)
                                    if let epgID = mapping.customEPGChannelID {
                                        Text("Eşleşen EPG ID: \(epgID)")
                                            .font(.caption2)
                                            .foregroundStyle(Color(hex: "#0A84FF"))
                                    }
                                }

                                Spacer()

                                Text(timeShiftText(mapping.timeShiftHours))
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(mapping.timeShiftHours != 0 ? Color(hex: "#0A84FF").opacity(0.2) : Color.white.opacity(0.08))
                                    )
                                    .foregroundStyle(mapping.timeShiftHours != 0 ? Color(hex: "#0A84FF") : .secondary)
                            }
                        }
                    } header: {
                        Text("Kanal Bazlı EPG Eşleştirmeleri (\(store.channelEPGMappings.count))")
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
                            dismiss()
                        }
                    }
                }
                .sheet(isPresented: Binding(
                    get: { store.isAddCustomEPGSourceSheetPresented },
                    set: { store.send(.setAddCustomEPGSourceSheetPresented($0)) }
                )) {
                    addSourceSheet
                }
        }
    }

    // MARK: - Add Source Sheet

    private var addSourceSheet: some View {
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
                        store.send(.addCustomEPGSource)
                    } label: {
                        HStack {
                            Spacer()
                            if store.isCustomEPGLoading {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("Kaydet ve Ayrıştır")
                                    .bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(store.newCustomEPGName.isEmpty || store.newCustomEPGURLString.isEmpty || store.isCustomEPGLoading)
                }
            }
            .navigationTitle("Yeni XMLTV Kaynağı")
            #if !os(tvOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Vazgeç") {
                            store.send(.setAddCustomEPGSourceSheetPresented(false))
                        }
                    }
                }
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
