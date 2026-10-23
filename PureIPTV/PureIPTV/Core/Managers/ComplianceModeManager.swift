import Foundation

public final class ComplianceModeManager: @unchecked Sendable {
    public static let shared = ComplianceModeManager()

    private let storageKey = "pureiptv_compliance_demo_mode"
    private var isEnabled: Bool = false

    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: storageKey)
    }

    public var isComplianceModeActive: Bool {
        get { isEnabled }
        set {
            isEnabled = newValue
            UserDefaults.standard.set(newValue, forKey: storageKey)
        }
    }

    public static let safeLiveChannels: [MediaModels.Item] = [
        MediaModels.Item(
            id: "safe_nasa_tv",
            title: "NASA TV HD (Public Domain)",
            streamURL: URL(string: "https://ntv1.akamaized.net/hls/live/2014075/NASA-NTV1-HLS/master.m3u8"),
            coverURL: URL(string: "https://images-assets.nasa.gov/image/PIA24653/PIA24653~thumb.jpg"),
            categoryID: "Bilim & Belgesel",
            type: .live
        ),
        MediaModels.Item(
            id: "safe_redbull_tv",
            title: "Red Bull TV Live",
            streamURL: URL(string: "https://rbmn-live.akamaized.net/hls/live/590964/BoRB-AT/master.m3u8"),
            coverURL: nil,
            categoryID: "Spor & Macera",
            type: .live
        ),
    ]

    public static let safeMovies: [MediaModels.Item] = [
        MediaModels.Item(
            id: "safe_bbb",
            title: "Big Buck Bunny (Creative Commons)",
            streamURL: URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"),
            coverURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c5/Big_buck_bunny_poster_big.jpg/440px-Big_buck_bunny_poster_big.jpg"),
            categoryID: "Açık Kaynak Animasyon",
            type: .vod
        ),
        MediaModels.Item(
            id: "safe_sintel",
            title: "Sintel (Blender Foundation)",
            streamURL: URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4"),
            coverURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/8/8f/Sintel_poster.jpg/440px-Sintel_poster.jpg"),
            categoryID: "Açık Kaynak Animasyon",
            type: .vod
        ),
        MediaModels.Item(
            id: "safe_tears_of_steel",
            title: "Tears of Steel (Blender Sci-Fi)",
            streamURL: URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4"),
            coverURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/5/52/Tears_of_Steel_poster.jpg/440px-Tears_of_Steel_poster.jpg"),
            categoryID: "Bilim Kurgu",
            type: .vod
        ),
    ]
}
