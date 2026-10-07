import Kingfisher
import SwiftUI

public struct CachedImage<Placeholder: View>: View {
    let url: URL?
    let placeholder: () -> Placeholder

    public init(url: URL?, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.placeholder = placeholder
    }

    public var body: some View {
        if let url {
            KFImage(url)
                .placeholder {
                    placeholder()
                }
                .resizable()
        } else {
            placeholder()
        }
    }
}
