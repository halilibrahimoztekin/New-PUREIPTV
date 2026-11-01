import ComposableArchitecture
import SwiftUI

struct HiddenMediaManagementRouteView: View {
    let routeStore: StoreOf<HiddenMediaManagementRouteFeature>

    var body: some View {
        HiddenMediaManagementView(
            store: routeStore.scope(state: \.manager, action: \.manager),
            onClose: { routeStore.send(.closeTapped) }
        )
    }
}

private struct HiddenMediaManagementView: View {
    @Bindable var store: StoreOf<HiddenMediaManagementFeature>
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(AppStrings.Settings.hiddenMediaManagement)
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                    Text(AppStrings.Settings.hiddenMediaManagementDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 20)
                Button(action: onClose) {
                    Label(AppStrings.Common.close, systemImage: "xmark")
                }
                .buttonStyle(.bordered)
                .accessibilityHint(AppStrings.Common.back)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)

            if store.isLoading {
                ProgressView(AppStrings.Common.loading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = store.errorMessage {
                VStack(spacing: 16) {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button(AppStrings.Common.retry) {
                        store.send(.onAppear)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(32)
            } else if store.items.isEmpty {
                ContentUnavailableView(
                    AppStrings.Settings.hiddenMediaManagement,
                    systemImage: "eye",
                    description: Text(AppStrings.Settings.noHiddenMedia)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(store.items) { entry in
                            itemRow(entry)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 32)
                }
                #if os(tvOS)
                .focusSection()
                #endif
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear { store.send(.onAppear) }
        #if os(tvOS)
            .onExitCommand(perform: onClose)
        #endif
    }

    private func playlistName(for entry: HiddenMediaEntry) -> String {
        guard let playlistID = entry.identity.playlistID else {
            return AppStrings.Settings.defaultMediaSource
        }
        return store.playlistNames[playlistID] ?? String(playlistID.uuidString.prefix(8))
    }

    private func itemRow(_ entry: HiddenMediaEntry) -> some View {
        HStack(spacing: 18) {
            Image(systemName: entry.identity.type == "series" ? "play.tv.fill" : "film.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 54, height: 54)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(entry.title)
                    .font(.headline)
                    .lineLimit(2)
                Text("\(entry.identity.type == "series" ? AppStrings.Series.title : AppStrings.VOD.title) · \(playlistName(for: entry))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 12)
            Button {
                guard !store.pendingRestoreIDs.contains(entry.id) else { return }
                store.send(.restoreTapped(entry))
            } label: {
                if store.pendingRestoreIDs.contains(entry.id) {
                    ProgressView()
                        .frame(minWidth: 96, minHeight: 44)
                } else {
                    Label(AppStrings.Common.restoreMediaItem, systemImage: "eye")
                }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("\(AppStrings.Common.restoreMediaItem): \(entry.title)")
        }
        .padding(16)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
