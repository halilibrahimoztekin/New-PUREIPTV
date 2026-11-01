(() => {
  "use strict";

  const context = cast.framework.CastReceiverContext.getInstance();
  const playerManager = context.getPlayerManager();

  playerManager.setMessageInterceptor(cast.framework.messages.MessageType.LOAD, request => {
    const requestedHeaders = request.media?.customData?.httpHeaders;
    const userAgent = typeof requestedHeaders?.["User-Agent"] === "string"
      ? requestedHeaders["User-Agent"].slice(0, 1024)
      : "";

    const playbackConfig = new cast.framework.PlaybackConfig();
    if (userAgent) {
      const applyUserAgent = requestInfo => {
        requestInfo.headers["User-Agent"] = userAgent;
      };
      playbackConfig.manifestRequestHandler = applyUserAgent;
      playbackConfig.segmentRequestHandler = applyUserAgent;
    }

    playerManager.setPlaybackConfig(playbackConfig);
    return request;
  });

  context.start();
})();
