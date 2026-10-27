import ComposableArchitecture
import SwiftUI

public struct ProfileSelectionView: View {
    @Bindable var store: StoreOf<ProfileSelectionFeature>
    @FocusState private var retryButtonFocused: Bool

    public init(store: StoreOf<ProfileSelectionFeature>) {
        self.store = store
    }

    private var isBlockingContent: Bool {
        store.isLoadingProfiles || store.isPerformingProfileOperation || store.errorMessage != nil
    }

    public var body: some View {
        ZStack {
            Group {
                #if os(tvOS)
                    ProfileSelectionView_tvOS(store: store)
                #else
                    ProfileSelectionView_iOS(store: store)
                #endif
            }
            .allowsHitTesting(!isBlockingContent)
            .disabled(isBlockingContent)
            .accessibilityHidden(isBlockingContent)

            if isBlockingContent {
                Color.black.opacity(0.82)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)

                VStack(spacing: 20) {
                    if let errorMessage = store.errorMessage {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                            .accessibilityHidden(true)
                        Text(AppStrings.Startup.profilesUnavailableTitle)
                            .font(.title2.weight(.semibold))
                            .multilineTextAlignment(.center)
                        Text(AppStrings.Startup.profilesUnavailableMessage)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        if !errorMessage.isEmpty {
                            Text(AppStrings.Startup.supportCode(errorMessage))
                                .font(.callout)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.tertiary)
                        }

                        Button(AppStrings.Common.retry) {
                            store.send(.retry)
                        }
                        .buttonStyle(.borderedProminent)
                        .focused($retryButtonFocused)

                        if store.hasLoadedProfiles {
                            Button(AppStrings.Common.close) {
                                store.send(.dismissError)
                            }
                            .buttonStyle(.bordered)
                        }
                    } else {
                        ProgressView(AppStrings.Common.loading)
                            .controlSize(.large)
                            .accessibilityLabel(AppStrings.Common.loading)
                    }
                }
                .padding(32)
                .frame(maxWidth: 900)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
                .padding(32)
                .zIndex(1)
                #if os(tvOS)
                    .focusSection()
                #endif
            }
        }
        .task {
            await Task.yield()
            guard !Task.isCancelled else { return }
            await store.send(.onAppear).finish()
        }
        .onDisappear {
            store.send(.onDisappear)
        }
        .onChange(of: store.errorMessage) { _, message in
            if message != nil {
                retryButtonFocused = true
            }
        }
    }
}
