import AppIntents
import Foundation
import SwiftData

@available(iOS 16.0, tvOS 16.0, *)
public struct PlayLiveTVIntent: AppIntent {
    public static var title: LocalizedStringResource = "Canlı TV Aç"
    public static var description = IntentDescription("Belirtilen canlı TV kanalını PureIPTV'de açar.")

    @Parameter(title: "Kanal Adı")
    public var channelName: String

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        // AppIntents operate in background or open the app.
        // We will return a dialog and open the app.
        // The AppDelegate or AppCoordinator would handle deep links,
        // but for now, we just indicate success.
        .result(dialog: "PureIPTV açılıyor...")
    }
}

@available(iOS 16.0, tvOS 16.0, *)
public struct ContinueWatchingIntent: AppIntent {
    public static var title: LocalizedStringResource = "Kaldığım Yerden Devam Et"
    public static var description = IntentDescription("PureIPTV'de yarım bıraktığınız en son içeriği oynatır.")

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        // Here we could query SwiftData via SharedDatabaseConfig to find the last watched item
        .result(dialog: "En son izlediğiniz içerik açılıyor...")
    }
}

@available(iOS 16.0, tvOS 16.0, *)
public struct PureIPTVShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PlayLiveTVIntent(),
            phrases: [
                "\(.applicationName)'de canlı TV aç",
                "\(.applicationName) ile televizyon izle",
            ],
            shortTitle: "Canlı TV",
            systemImageName: "tv"
        )

        AppShortcut(
            intent: ContinueWatchingIntent(),
            phrases: [
                "\(.applicationName)'de kaldığım yerden devam et",
                "\(.applicationName)'de en son ne izliyordum",
            ],
            shortTitle: "Kaldığın Yerden İzle",
            systemImageName: "play.circle"
        )
    }
}
