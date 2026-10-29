# PureIPTV Google Cast receiver

This folder contains the CAF Custom Web Receiver. Cast devices load these static files from the URL registered for the receiver application.

## Configure and host

1. Register a **Custom Web Receiver** in the [Google Cast SDK Developer Console](https://developers.google.com/cast/docs/registration).
2. Host `index.html`, `receiver.css`, and `receiver.js` together, then set that URL in the receiver registration. For development, Google allows an HTTP URL on a reachable private network; published receiver apps must use HTTPS.
3. Set the returned eight-character `GOOGLE_CAST_RECEIVER_APPLICATION_ID` in the PureIPTV Xcode target’s Debug and Release build settings. The same value is substituted into `Info.plist` for Cast discovery.
4. Register each Cast device used with an unpublished receiver in the same Developer Console.

The project currently defaults this setting to `CC1AD845`, Google’s Default Media Receiver ID. PureIPTV intentionally disables its Cast sender for that ID; replace it with the registered Custom Receiver ID to enable Cast. Do not use a made-up ID. A command-line build can override the setting with `GOOGLE_CAST_RECEIVER_APPLICATION_ID=<registered-id>`.

The receiver must be reachable by the Cast device before a session can start. The app ID and receiver URL must refer to the same registered receiver.

## Media and request data

The sender and receiver accept HTTP(S) media URLs with HLS, DASH, MPEG-TS, or MP4 content types. Actual playback still depends on the Cast device and stream format. Only a validated User-Agent override is forwarded as an HTTP header; arbitrary headers and separate media-server credentials are not sent. The sender uses an opaque media ID and the receiver URL resolver so the source URL is not returned in Cast media status, though it is still sent in the initial load request.

The selected Cast device receives the stream URL so it can fetch the media directly. If that URL embeds provider credentials in its path, query, or URL userinfo (`username:password@host`), those values are included in the initial Cast load request and can be read by the receiver and Cast device. The sender excludes sources configured with separate Plex or Emby credentials.

## References

- [Custom Web Receiver overview](https://developers.google.com/cast/docs/web_receiver)
- [iOS sender setup](https://developers.google.com/cast/docs/ios_sender)
