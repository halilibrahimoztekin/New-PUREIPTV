# PureIPTV Google Cast receiver

This folder is a standalone Google Cast Custom Web Receiver. Host these files at a stable HTTPS URL, then register that URL as a **Custom Receiver** in the Google Cast SDK Developer Console. For development, Google permits an HTTP receiver URL on a reachable LAN address; a published receiver must use HTTPS.

## Configure the sender

1. Register the receiver in the Cast SDK Developer Console and note its eight-character application ID.
2. Host `index.html`, `receiver.js`, and `receiver.css` together. The receiver URL must be reachable by the Cast device.
3. Set `GOOGLE_CAST_RECEIVER_APPLICATION_ID` to the registered ID in both Debug and Release Xcode build settings. The checked-in `CC1AD845` value is Google's Default Media Receiver ID; this app intentionally does not start a Cast session with that default receiver.
4. Register the Cast device for development in the same console. A published receiver can be launched by other Cast devices.

The receiver accepts HTTP and HTTPS media URLs with the MIME types currently emitted by the iOS sender. It forwards only a validated `User-Agent` header to manifest and segment requests. It uses an opaque media ID and a URL resolver so the source URL is not repeated in Cast media status messages. The stream URL is still sent to the selected Cast device in the initial load request because that device fetches the stream directly.

The receiver does not store provider credentials or accept arbitrary request headers. Existing provider URLs that include their own authentication path or query continue to be fetched by the receiver; local Keychain credentials and Plex/Emby media-server credentials are not sent.
