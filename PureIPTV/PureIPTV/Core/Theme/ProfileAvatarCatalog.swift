import Foundation

enum ProfileAvatarCatalog {
    struct Option: Identifiable, Equatable {
        let name: String
        let symbolName: String

        var id: String {
            symbolName
        }
    }

    static let adultDefault = "person.crop.circle.fill"
    static let kidsDefault = "face.smiling.fill"

    static let options = [
        Option(name: "Klasik".localized, symbolName: adultDefault),
        Option(name: "Çocuk".localized, symbolName: kidsDefault),
        Option(name: "Kedi".localized, symbolName: "cat.fill"),
        Option(name: "Köpek".localized, symbolName: "dog.fill"),
        Option(name: "Oyun".localized, symbolName: "gamecontroller.fill"),
        Option(name: "Spor".localized, symbolName: "soccerball"),
        Option(name: "Müzik".localized, symbolName: "music.note"),
        Option(name: "Yıldız".localized, symbolName: "star.circle.fill"),
        Option(name: "Doğa".localized, symbolName: "leaf.fill"),
        Option(name: "Film".localized, symbolName: "film.fill"),
    ]

    static func defaultAvatar(isKidsMode: Bool) -> String {
        isKidsMode ? kidsDefault : adultDefault
    }

    static func validated(_ symbolName: String, isKidsMode: Bool) -> String {
        options.contains(where: { $0.symbolName == symbolName })
            ? symbolName
            : defaultAvatar(isKidsMode: isKidsMode)
    }
}
