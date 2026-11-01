import AVFoundation
import SwiftUI

struct AVPlayerSurfaceView: UIViewRepresentable {
    let player: AVPlayer
    let aspectRatioMode: VideoAspectRatioMode
    let forceSDROutput: Bool

    func makeUIView(context _: Context) -> PlayerLayerHostView {
        let view = PlayerLayerHostView()
        view.update(player: player, aspectRatioMode: aspectRatioMode, forceSDROutput: forceSDROutput)
        return view
    }

    func updateUIView(_ uiView: PlayerLayerHostView, context _: Context) {
        uiView.update(player: player, aspectRatioMode: aspectRatioMode, forceSDROutput: forceSDROutput)
    }
}

final class PlayerLayerHostView: UIView {
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
    }

    func update(player: AVPlayer, aspectRatioMode: VideoAspectRatioMode, forceSDROutput: Bool) {
        let gravity = aspectRatioMode.avLayerVideoGravity
        if playerLayer.player !== player {
            playerLayer.player = player
        }
        playerLayer.videoGravity = gravity
        if #available(iOS 26.0, tvOS 26.0, *) {
            playerLayer.preferredDynamicRange = forceSDROutput && !player.isExternalPlaybackActive ? .standard : .automatic
        }
        player.externalPlaybackVideoGravity = aspectRatioMode.externalPlaybackVideoGravity
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }
}

private extension VideoAspectRatioMode {
    var avLayerVideoGravity: AVLayerVideoGravity {
        switch self {
        case .fit: .resizeAspect
        case .fill, .zoom: .resizeAspectFill
        case .stretch: .resizeAspect
        }
    }

    var externalPlaybackVideoGravity: AVLayerVideoGravity {
        switch self {
        case .fit: .resizeAspect
        case .fill, .zoom: .resizeAspectFill
        case .stretch: .resize
        }
    }
}
