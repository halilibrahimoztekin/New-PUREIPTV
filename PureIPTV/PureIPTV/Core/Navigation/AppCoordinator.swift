import ComposableArchitecture
import SwiftUI
import UIKit
import XCoordinator

public final class AppCoordinator: NavigationCoordinator<AppRoute> {
    public nonisolated init() {
        super.init(initialRoute: nil)
        MainActor.assumeIsolated {
            self.rootViewController.setNavigationBarHidden(true, animated: false)
        }
    }

    override public nonisolated init(rootViewController: UINavigationController, initialRoute: AppRoute? = nil) {
        super.init(rootViewController: rootViewController, initialRoute: initialRoute)
        MainActor.assumeIsolated {
            self.rootViewController.setNavigationBarHidden(true, animated: false)
        }
    }

    override public nonisolated init(rootViewController: UINavigationController, root: Presentable) {
        super.init(rootViewController: rootViewController, root: root)
        MainActor.assumeIsolated {
            self.rootViewController.setNavigationBarHidden(true, animated: false)
        }
    }

    public var store: StoreOf<AppFeature>!

    public func setup(store: StoreOf<AppFeature>) {
        self.store = store
        // Trigger initial route
        if store.splashIsActive {
            trigger(.splash)
        } else if store.onboarding != nil {
            trigger(.onboarding)
        } else if !store.isOnboarded {
            trigger(.login)
        } else if store.profileSelection != nil {
            trigger(.profileSelection)
        } else if store.home != nil {
            trigger(.home)
        }
    }

    override public nonisolated func prepareTransition(for route: AppRoute) -> XCoordinator.NavigationTransition {
        MainActor.assumeIsolated {
            switch route {
            case .splash:
                let splashView = SplashView(store: store.scope(state: \.splash, action: \.splash))
                let vc = UIHostingController(rootView: splashView)
                vc.view.backgroundColor = .black
                return .set([vc])

            case .onboarding:
                if let onboardingStore = store.scope(state: \.onboarding, action: \.onboarding) {
                    let view = OnboardingView(store: onboardingStore)
                    let vc = UIHostingController(rootView: view)
                    vc.view.backgroundColor = .black
                    return .set([vc])
                }
                return .none()

            case .profileSelection:
                if let profileStore = store.scope(state: \.profileSelection, action: \.profileSelection) {
                    let view = ProfileSelectionView(store: profileStore)
                    let vc = UIHostingController(rootView: view)
                    vc.view.backgroundColor = .black
                    return .set([vc])
                }
                return .none()

            case .login:
                let loginView = AddPlaylistView(store: store.scope(state: \.addPlaylist, action: \.addPlaylist))
                let vc = UIHostingController(rootView: loginView)
                vc.view.backgroundColor = .black
                return .set([vc])

            case .home:
                if let homeStore = store.scope(state: \.home, action: \.home) {
                    let homeView = HomeView(store: homeStore)
                    let vc = UIHostingController(rootView: homeView)
                    vc.view.backgroundColor = .black
                    return .set([vc])
                }
                return .none()

            case .player:
                if let playerStore = store.scope(state: \.player, action: \.player) {
                    let playerView = PlayerView(store: playerStore)
                    let vc = UIHostingController(rootView: playerView)
                    vc.view.backgroundColor = .black
                    vc.modalPresentationStyle = .fullScreen
                    return .present(vc)
                }
                return .none()

            case .dismissPlayer:
                return .dismiss()

            case .seriesDetail:
                if let seriesDetailStore = store.scope(state: \.seriesDetail, action: \.seriesDetail.presented) {
                    let seriesDetailView = SeriesDetailView(store: seriesDetailStore)
                    let vc = UIHostingController(rootView: seriesDetailView)
                    vc.view.backgroundColor = .black
                    return .push(vc)
                }
                return .none()

            case .dismissSeriesDetail:
                return .pop()

            case .vodDetail:
                if let vodDetailStore = store.scope(state: \.vodDetail, action: \.vodDetail.presented) {
                    let vodDetailView = VODDetailView(store: vodDetailStore)
                    let vc = UIHostingController(rootView: vodDetailView)
                    vc.view.backgroundColor = .black
                    return .push(vc)
                }
                return .none()

            case .dismissVodDetail:
                return .pop()

            case .playlistManagement:
                if let playlistStore = store.scope(state: \.playlistManagement, action: \.playlistManagement.presented) {
                    let playlistView = PlaylistManagementView(store: playlistStore)
                    let vc = UIHostingController(rootView: playlistView)
                    vc.view.backgroundColor = .black
                    return .push(vc)
                }
                return .none()

            case .dismissPlaylistManagement:
                return .pop()

            case .paywall:
                if let paywallStore = store.scope(state: \.paywall, action: \.paywall.presented) {
                    let paywallView = PaywallView(store: paywallStore)
                    let vc = UIHostingController(rootView: paywallView)
                    vc.view.backgroundColor = .black
                    vc.modalPresentationStyle = .fullScreen
                    return .present(vc)
                }
                return .none()

            case .dismissPaywall:
                return .dismiss()
            }
        }
    }
}
