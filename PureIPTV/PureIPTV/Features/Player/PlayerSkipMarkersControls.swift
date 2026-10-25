import ComposableArchitecture
import SwiftUI

struct PlayerSkipMarkersControls: View {
    @Bindable var store: StoreOf<PlayerFeature>
    let onInteraction: () -> Void

    var body: some View {
        if store.canManageSkipMarkers {
            HStack(spacing: 12) {
                if let activeKind = store.activeSkipMarkerKind {
                    Button {
                        onInteraction()
                        store.send(.skipMarkedSegment(activeKind))
                    } label: {
                        Label(skipTitle(for: activeKind), systemImage: "forward.end.fill")
                    }
                    .accessibilityLabel(skipTitle(for: activeKind))
                }

                Menu {
                    markerSection(.intro)
                    markerSection(.credits)
                } label: {
                    Label(AppStrings.Player.skipMarkers, systemImage: "bookmark")
                }
                .accessibilityLabel(AppStrings.Player.skipMarkers)
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private func markerSection(_ kind: PlaybackSkipMarkerKind) -> some View {
        let marker = store.skipMarkers[kind]
        let duration = Double(store.totalTime.components.seconds)
        let current = Double(store.currentTime.components.seconds)

        Section(kind == .intro ? AppStrings.Player.introMarkerTitle : AppStrings.Player.creditsMarkerTitle) {
            Button(AppStrings.Player.markStartHere) {
                onInteraction()
                store.send(.setSkipMarkerBoundary(kind: kind, isStart: true))
            }
            .disabled(duration <= 0 || current >= duration)

            Button(AppStrings.Player.markEndHere) {
                onInteraction()
                store.send(.setSkipMarkerBoundary(kind: kind, isStart: false))
            }
            .disabled(marker.startSeconds == nil || current <= (marker.startSeconds ?? .infinity))

            Button(AppStrings.Player.clearMarker, role: .destructive) {
                onInteraction()
                store.send(.clearSkipMarker(kind))
            }
            .disabled(marker.startSeconds == nil && marker.endSeconds == nil)
        }
    }

    private func skipTitle(for kind: PlaybackSkipMarkerKind) -> String {
        kind == .intro ? AppStrings.Player.skipIntro : AppStrings.Player.skipCredits
    }
}
