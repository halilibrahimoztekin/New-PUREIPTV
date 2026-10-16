#if os(tvOS)
    import Foundation
    import TVServices

    /// Apple TV Ana Ekranı Top Shelf dinamik içerik sağlayıcısı.
    /// Uygulama üst sırada yer aldığında kullanıcının Kaldığı Yerden Devam Et,
    /// Favori Kanallar ve Yeni Filmler listelerini derin bağlantılarla (Deep Link) sunar.
    public final class PureIPTVTopShelfContentProvider: TVTopShelfContentProvider, @unchecked Sendable {
        override public init() {
            super.init()
        }

        override public func loadTopShelfContent(completionHandler: @escaping ((any TVTopShelfContent)?) -> Void) {
            guard let data = TopShelfService.shared.loadTopShelfData() else {
                completionHandler(nil)
                return
            }

            var sections: [TVTopShelfItemCollection<TVTopShelfSectionedItem>] = []

            // 1. Kaldığın Yerden İzle (Continue Watching)
            if !data.continueWatching.isEmpty {
                let items: [TVTopShelfSectionedItem] = data.continueWatching.compactMap { (dto: TopShelfItemDTO) -> TVTopShelfSectionedItem? in
                    guard let deepLink = URL(string: dto.deepLinkURL) else { return nil }
                    let item = TVTopShelfSectionedItem(identifier: dto.id)
                    if let subtitle = dto.subtitle, !subtitle.isEmpty {
                        item.title = "\(dto.title) - \(subtitle)"
                    } else {
                        item.title = dto.title
                    }
                    if let imageURLStr = dto.imageURL, let imageURL = URL(string: imageURLStr) {
                        item.setImageURL(imageURL, for: .screenScale1x)
                        item.setImageURL(imageURL, for: .screenScale2x)
                    }
                    if let progress = dto.progress {
                        item.playbackProgress = progress
                    }
                    item.imageShape = .poster
                    item.displayAction = TVTopShelfAction(url: deepLink)
                    item.playAction = TVTopShelfAction(url: deepLink)
                    return item
                }
                if !items.isEmpty {
                    let section = TVTopShelfItemCollection(items: items)
                    section.title = "Kaldığın Yerden İzle"
                    sections.append(section)
                }
            }

            // 2. Favori Kanallar (Favorite Channels)
            if !data.favoriteChannels.isEmpty {
                let items: [TVTopShelfSectionedItem] = data.favoriteChannels.compactMap { (dto: TopShelfItemDTO) -> TVTopShelfSectionedItem? in
                    guard let deepLink = URL(string: dto.deepLinkURL) else { return nil }
                    let item = TVTopShelfSectionedItem(identifier: dto.id)
                    item.title = dto.title
                    if let imageURLStr = dto.imageURL, let imageURL = URL(string: imageURLStr) {
                        item.setImageURL(imageURL, for: .screenScale1x)
                        item.setImageURL(imageURL, for: .screenScale2x)
                    }
                    item.imageShape = .hdtv
                    item.displayAction = TVTopShelfAction(url: deepLink)
                    item.playAction = TVTopShelfAction(url: deepLink)
                    return item
                }
                if !items.isEmpty {
                    let section = TVTopShelfItemCollection(items: items)
                    section.title = "Favori Kanallar"
                    sections.append(section)
                }
            }

            // 3. Yeni Eklenen Filmler (Recent Movies)
            if !data.recentMovies.isEmpty {
                let items: [TVTopShelfSectionedItem] = data.recentMovies.compactMap { (dto: TopShelfItemDTO) -> TVTopShelfSectionedItem? in
                    guard let deepLink = URL(string: dto.deepLinkURL) else { return nil }
                    let item = TVTopShelfSectionedItem(identifier: dto.id)
                    item.title = dto.title
                    if let imageURLStr = dto.imageURL, let imageURL = URL(string: imageURLStr) {
                        item.setImageURL(imageURL, for: .screenScale1x)
                        item.setImageURL(imageURL, for: .screenScale2x)
                    }
                    item.imageShape = .poster
                    item.displayAction = TVTopShelfAction(url: deepLink)
                    item.playAction = TVTopShelfAction(url: deepLink)
                    return item
                }
                if !items.isEmpty {
                    let section = TVTopShelfItemCollection(items: items)
                    section.title = "Yeni Filmler"
                    sections.append(section)
                }
            }

            guard !sections.isEmpty else {
                completionHandler(nil)
                return
            }
            completionHandler(TVTopShelfSectionedContent(sections: sections))
        }
    }
#endif
