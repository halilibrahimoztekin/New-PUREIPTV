(function () {
  "use strict";

  const context = cast.framework.CastReceiverContext.getInstance();
  const playerManager = context.getPlayerManager();
  const allowedContentTypes = new Set([
    "application/x-mpegurl",
    "application/vnd.apple.mpegurl",
    "application/dash+xml",
    "video/mp2t",
    "video/mp4",
  ]);

  function mediaURL(loadRequest) {
    const value = loadRequest && loadRequest.media && loadRequest.media.contentUrl;
    if (typeof value !== "string" || value.length === 0) return null;

    try {
      const parsed = new URL(value);
      if (parsed.protocol !== "http:" && parsed.protocol !== "https:") return null;
      return parsed.href;
    } catch (_) {
      return null;
    }
  }

  function safeHeaders(media) {
    const raw = media && media.customData && media.customData.httpHeaders;
    if (raw === undefined || raw === null) return {};
    if (typeof raw !== "object" || Array.isArray(raw)) return null;

    const headers = {};
    for (const [name, value] of Object.entries(raw)) {
      if (name.toLowerCase() !== "user-agent") continue;
      if (typeof value !== "string" || value.length === 0 || value.length > 1024) return null;
      if (/[\u0000-\u001f\u007f]/.test(value)) return null;
      headers["User-Agent"] = value;
    }
    return headers;
  }

  function loadError() {
    const error = new cast.framework.messages.ErrorData(
      cast.framework.messages.ErrorType.LOAD_FAILED
    );
    error.reason = cast.framework.messages.ErrorReason.INVALID_PARAM;
    return error;
  }

  playerManager.setMessageInterceptor(
    cast.framework.messages.MessageType.LOAD,
    (loadRequest) => {
      const url = mediaURL(loadRequest);
      const media = loadRequest && loadRequest.media;
      const contentType = media && typeof media.contentType === "string"
        ? media.contentType.toLowerCase()
        : "";

      if (!url || !allowedContentTypes.has(contentType) || !safeHeaders(media)) {
        return loadError();
      }
      return loadRequest;
    }
  );

  playerManager.setMediaUrlResolver((loadRequest) => mediaURL(loadRequest));

  playerManager.setMediaPlaybackInfoHandler((loadRequest, playbackConfig) => {
    const headers = safeHeaders(loadRequest && loadRequest.media);
    if (!headers || Object.keys(headers).length === 0) return playbackConfig;

    const applyHeaders = (requestInfo) => {
      requestInfo.headers = Object.assign({}, requestInfo.headers || {}, headers);
      return requestInfo;
    };

    playbackConfig.manifestRequestHandler = applyHeaders;
    playbackConfig.segmentRequestHandler = applyHeaders;
    return playbackConfig;
  });

  context.start();
})();
