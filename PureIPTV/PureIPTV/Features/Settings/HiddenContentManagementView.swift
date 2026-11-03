import ComposableArchitecture
import SwiftUI

public struct HiddenContentManagementView: View {
    @Bindable var store: StoreOf<SettingsFeature>
    @State private var selectedTab: Tab = .channels
    @FocusState private var focusedKeypadButton: String?
    @FocusState private var isPinFieldFocused: Bool

    public enum Tab: String, CaseIterable, Identifiable {
        case channels = "Kanallar"
        case categories = "Kategoriler"

        public var id: String {
            rawValue
        }
    }

    public init(store: StoreOf<SettingsFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AppColors.surface.ignoresSafeArea()

                if store.isUnlockingHiddenContent {
                    pinUnlockOverlay
                } else {
                    mainContent
                }
            }
            .navigationTitle("Gizlenen İçerikler")
            #if !os(tvOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Kapat") {
                            store.send(.closeHiddenContentManagement)
                        }
                        .foregroundColor(AppColors.textPrimary.opacity(0.8))
                    }

                    if !store.isUnlockingHiddenContent {
                        ToolbarItem(placement: .primaryAction) {
                            Menu {
                                Button(role: .destructive) {
                                    #if !os(tvOS)
                                        HapticManager.shared.trigger(.warning)
                                    #endif
                                    store.send(.unhideAllChannelsFromSettings)
                                } label: {
                                    Label("Tüm Kanalları Görünür Yap", systemImage: "tv")
                                }

                                Button(role: .destructive) {
                                    #if !os(tvOS)
                                        HapticManager.shared.trigger(.warning)
                                    #endif
                                    store.send(.unblacklistAllCategoriesFromSettings)
                                } label: {
                                    Label("Tüm Kategori Kilitlerini Kaldır", systemImage: "folder.badge.minus")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(AppFonts.bodyLarge)
                                    .foregroundColor(AppColors.primary)
                            }
                        }
                    }
                }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 16) {
            // Segmented Tab Picker
            Picker("Sekme", selection: $selectedTab) {
                Text("Gizlenen Kanallar (\(store.hiddenChannelsList.count))").tag(Tab.channels)
                Text("Kara Liste Kategoriler (\(store.blacklistedCategoriesList.count))").tag(Tab.categories)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.top, 12)

            if selectedTab == .channels {
                channelsListView
            } else {
                categoriesListView
            }
        }
    }

    // MARK: - Channels List View

    @ViewBuilder
    private var channelsListView: some View {
        if store.hiddenChannelsList.isEmpty {
            emptyState(
                icon: "tv.slash",
                title: "Gizlenen Kanal Yok",
                subtitle: "Oynatıcı çekmecesinden veya kanal listesinden gizlediğiniz kanallar burada listelenir."
            )
        } else {
            List {
                ForEach(store.hiddenChannelsList) { item in
                    itemRow(
                        item: item,
                        icon: "tv.fill",
                        accentColor: AppColors.primary,
                        onUnhide: {
                            store.send(.unhideChannelFromSettings(item.id))
                        }
                    )
                }
            }
            #if !os(tvOS)
            .scrollContentBackground(.hidden)
            #endif
        }
    }

    // MARK: - Categories List View

    @ViewBuilder
    private var categoriesListView: some View {
        if store.blacklistedCategoriesList.isEmpty {
            emptyState(
                icon: "folder.badge.minus",
                title: "Kara Liste Kategori Yok",
                subtitle: "Kategori yönetiminden veya ebeveyn denetiminden kilitlediğiniz kategoriler burada görünür."
            )
        } else {
            List {
                ForEach(store.blacklistedCategoriesList) { item in
                    itemRow(
                        item: item,
                        icon: "folder.fill.badge.minus",
                        accentColor: AppColors.premium,
                        onUnhide: {
                            store.send(.unblacklistCategoryFromSettings(item.id))
                        }
                    )
                }
            }
            #if !os(tvOS)
            .scrollContentBackground(.hidden)
            #endif
        }
    }

    // MARK: - Item Row

    private func itemRow(item: HiddenItemDTO, icon: String, accentColor: Color, onUnhide: @escaping () -> Void) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.18))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(AppFonts.titleSmall)
                    .foregroundStyle(accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(AppFonts.bodyBold)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)

                Text("Gizlenme Tarihi: \(formattedDate(item.hiddenAt))")
                    .font(AppFonts.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()

            Button {
                #if !os(tvOS)
                    HapticManager.shared.trigger(.light)
                #endif
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    onUnhide()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "eye.fill")
                        .font(AppFonts.captionBold)
                    Text("Görünür Yap")
                        .font(AppFonts.captionBold)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppColors.success.opacity(0.18))
                .foregroundStyle(AppColors.success)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(AppColors.success.opacity(0.4), lineWidth: 1)
                )
            }
            #if os(tvOS)
            .tvFocusEffect(shape: .capsule)
            #else
            .buttonStyle(.plain)
            #endif
        }
        .padding(.vertical, 4)
        .listRowBackground(AppColors.glassPlate)
    }

    // MARK: - Empty State

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppColors.surfaceElevated)
                    .frame(width: 80, height: 80)

                Image(systemName: icon)
                    .font(AppFonts.displayMedium)
                    .foregroundStyle(AppColors.textSecondary)
            }

            VStack(spacing: 6) {
                Text(title)
                    .font(AppFonts.titleSmall)
                    .foregroundStyle(AppColors.textPrimary)

                Text(subtitle)
                    .font(AppFonts.bodySmall)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }

            Spacer()
        }
    }

    // MARK: - PIN Unlock Overlay

    private var pinUnlockOverlay: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 20)

            Image(systemName: "lock.shield.fill")
                .font(AppFonts.displayLarge)
                .foregroundColor(AppColors.destructive)

            VStack(spacing: 6) {
                Text("Ebeveyn Kodu Gerekli")
                    .font(AppFonts.title)
                    .foregroundColor(AppColors.textPrimary)

                Text("Gizlenen kanal ve kategorileri yönetmek için 4 haneli PIN kodunuzu girin.")
                    .font(AppFonts.bodySmall)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // PIN Dots
            HStack(spacing: 20) {
                ForEach(0 ..< 4, id: \.self) { index in
                    let isFilled = store.hiddenContentUnlockPIN.count > index
                    ZStack {
                        Circle()
                            .stroke(isFilled ? AppColors.primary : AppColors.borderMedium, lineWidth: 2)
                            .frame(width: 20, height: 20)

                        if isFilled {
                            Circle()
                                .fill(AppColors.primary)
                                .frame(width: 12, height: 12)
                        }
                    }
                    .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isFilled)
                }
            }
            .padding(.vertical, 8)

            if let error = store.hiddenContentUnlockError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(AppFonts.footnote)
                    Text(error)
                        .font(AppFonts.footnote.weight(.semibold))
                }
                .foregroundColor(AppColors.destructive)
            }

            #if os(tvOS)
                tvOSKeypad
            #else
                SecureField("", text: Binding(
                    get: { store.hiddenContentUnlockPIN },
                    set: { store.send(.hiddenContentUnlockPINChanged($0)) }
                ))
                .keyboardType(.numberPad)
                .focused($isPinFieldFocused)
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .onAppear {
                    isPinFieldFocused = true
                }
            #endif

            Button("Vazgeç") {
                store.send(.cancelHiddenContentUnlock)
                store.send(.closeHiddenContentManagement)
            }
            .foregroundColor(AppColors.textSecondary)
            .padding(.top, 8)

            Spacer(minLength: 20)
        }
    }

    #if os(tvOS)
        private var tvOSKeypad: some View {
            VStack(spacing: 12) {
                ForEach(0 ..< 3) { row in
                    HStack(spacing: 16) {
                        ForEach(1 ... 3, id: \.self) { col in
                            let digit = row * 3 + col
                            keypadButton(label: "\(digit)") {
                                appendDigit("\(digit)")
                            }
                        }
                    }
                }

                HStack(spacing: 16) {
                    keypadButton(icon: "arrow.counterclockwise") {
                        store.send(.hiddenContentUnlockPINChanged(""))
                    }

                    keypadButton(label: "0") {
                        appendDigit("0")
                    }

                    keypadButton(icon: "delete.left.fill") {
                        if !store.hiddenContentUnlockPIN.isEmpty {
                            store.send(.hiddenContentUnlockPINChanged(String(store.hiddenContentUnlockPIN.dropLast())))
                        }
                    }
                }
            }
        }

        private func keypadButton(label: String? = nil, icon: String? = nil, action: @escaping () -> Void) -> some View {
            let key = label ?? icon ?? ""
            return Button(action: action) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(focusedKeypadButton == key ? AppColors.textPrimary : AppColors.borderMedium)
                        .frame(width: 72, height: 48)

                    if let label {
                        Text(label)
                            .font(AppFonts.titleSmall)
                            .foregroundColor(focusedKeypadButton == key ? AppColors.oledBlack : AppColors.textPrimary)
                    } else if let icon {
                        Image(systemName: icon)
                            .font(AppFonts.titleSmall)
                            .foregroundColor(focusedKeypadButton == key ? AppColors.oledBlack : AppColors.textPrimary)
                    }
                }
            }
            .buttonStyle(.plain)
            .focused($focusedKeypadButton, equals: key)
        }

        private func appendDigit(_ digit: String) {
            guard store.hiddenContentUnlockPIN.count < 4 else { return }
            store.send(.hiddenContentUnlockPINChanged(store.hiddenContentUnlockPIN + digit))
        }
    #endif

    private func formattedDate(_ date: Date) -> String {
        AppFormatters.mediumDateShortTime(date)
    }
}
