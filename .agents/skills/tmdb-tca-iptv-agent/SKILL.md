---
name: tmdb-tca-iptv-agent
description: Integrate TMDB metadata, matching, logos, posters, and backdrops in this SwiftUI and TCA IPTV app. Use when changing TMDB networking, response models, catalog artwork, or movie and series presentation.
---

# TMDB and TCA for PureIPTV

Use this skill when modifying TMDB integration or TMDB-backed movie and series UI in this repository. Treat TMDB's current official API docs as the authority for endpoint behavior. This file records project conventions and verified implementation guidance; it does not authorize unrelated product changes.

## Official references

- TMDB API v3 getting started and configuration: <https://developer.themoviedb.org/docs/getting-started>
- Application authentication: <https://developer.themoviedb.org/docs/authentication-application>
- Detail `append_to_response`: <https://developer.themoviedb.org/docs/append-to-response>
- Image languages: <https://developer.themoviedb.org/docs/image-languages>
- Image URL and file-size basics: <https://developer.themoviedb.org/docs/image-basics>
- Movie images: <https://developer.themoviedb.org/reference/movie-images>
- TV images: <https://developer.themoviedb.org/reference/tv-series-images>
- Rate limits: <https://developer.themoviedb.org/docs/rate-limiting>
- TMDB API attribution: <https://developer.themoviedb.org/docs/faq>
- TCA: <https://github.com/pointfreeco/swift-composable-architecture>
- Swift Dependencies: <https://github.com/pointfreeco/swift-dependencies>

Recheck these references if endpoint behavior or SDK versions may have changed.

## Project map and conventions

- `PureIPTV/Core/Clients/TMDBClient.swift`: TCA `@DependencyClient`, live implementation, and test dependency.
- `PureIPTV/Core/Persistence/TMDBAPIKeyStore.swift`: protected API-key storage. Do not print or include credentials in logs, URLs in diagnostics, or user-facing errors.
- `PureIPTV/Core/Models/DTO/TMDBMovieDTO.swift`: Codable response DTOs. API fields that can be absent or `null` must stay optional.
- `PureIPTV/Features/VODDetail/VODDetailFeature.swift` and `PureIPTV/Features/SeriesDetail/SeriesDetailFeature.swift`: TCA search, match overrides, detail loading, and cancellation.
- `PureIPTV/Core/Models/Presentation/TMDBSearchMatchSelector.swift`: high-confidence automatic search selection; uncertain matches stay available to the manual picker.
- `PureIPTV/Core/Clients/TMDBMatchOverrideClient.swift`: durable per-playlist manual match overrides. A user-selected match takes precedence over an automatic search result.
- `PureIPTV/Core/UI/PlaylistAsyncImage.swift` and `PlaylistArtworkRequest.swift`: playlist-aware artwork requests and Kingfisher caching.
- `PureIPTV/Core/Clients/TMDBTitleLogoCache.swift` and `PureIPTV/Core/UI/TMDBTitleLogoView.swift`: bounded sharing of title-logo and backdrop paths learned from detail responses with catalog and hero views; only the small file-path indexes are persisted.
- `PureIPTV/DesignSystem/TVMediaCards.swift`: native tvOS media cards and focus presentation.

Keep API transport in clients, response parsing in DTOs, and view composition in SwiftUI. Follow the TCA version pinned by this project and its existing `@DependencyClient`/`DependencyKey` conventions; do not introduce another networking or image framework for TMDB.

## Authentication and requests

TMDB v3 application authentication officially supports either the v3 `api_key` query parameter or an API Read Access Token sent as `Authorization: Bearer …`. Both have equivalent API access. Preserve the project's existing Keychain-backed API-key flow unless the user explicitly requests an authentication migration. Never hard-code a key or token. Build query strings with `URLComponents` and `URLQueryItem`.

Use media-specific matching endpoints when the content type is already known:

- Movies: `/search/movie`, then `/movie/{movie_id}`.
- Series: `/search/tv`, then `/tv/{series_id}`.
- `/search/multi` is for genuinely mixed movie/TV/person searches. Its `media_type` makes the result polymorphic; do not decode all results as one movie/TV shape.

Do not trust the first search result blindly. Preserve an explicit user match; otherwise filter to exact normalized title/original-title matches, including the provider title before a spaced subtitle delimiter. Normalize Turkish dotless `ı` to `i` in addition to case and diacritic folding; IPTV feeds often transliterate it while TMDB stores the correctly accented Turkish title. Use release year to rank same-title candidates; if the provider year is stale, use TMDB's relevance order only to break ties between exact title matches. Non-exact and unresolved matches stay available through the existing manual picker rather than automatically attaching details or artwork. The manual picker can show search results for the cleaned provider title, but only an explicit selection creates an override. A text-only fallback is preferable to confidently presenting the wrong title's metadata.

Use `append_to_response` to combine detail subresources that the screen actually needs, for example `credits,similar,videos,images`. It reduces round trips but adds payload: do not append every possible subresource by default. For `images`, specify `include_image_language=tr,en,null` along with `language=tr-TR`; `include_image_language` is the image fallback filter and uses image language codes. Verify the exact language rules against the official image-language page.

Respect HTTP failures, especially `429`; TMDB says its old fixed limit was disabled but still applies upper limits and asks clients to honor 429 responses. Avoid request-per-card strategies, retry storms, and unbounded `TaskGroup` fan-out. Prefer existing detail responses, bounded concurrency, cancellation, and cached results.

## Image paths, sizes, and title logos

TMDB image URLs are made from an image base URL, an allowed file-size token, and the response `file_path`. The `/configuration` response describes the base URL and supported sizes. Do not store assembled URLs in API DTOs; keep `file_path` and construct a URL through a small typed helper at the presentation boundary. Do not concatenate arbitrary size strings or accept a full remote URL where a TMDB path is expected.

Use a display-appropriate size, not `original` for every image. For this project, start with `w500` for poster grids, `w780`/`w1280` for detail backdrops, and a bounded PNG size for title logos. Use `original` only when the selected artwork requires it and its download/decode cost is justified. Downsample to the actual rendered point size and display scale with Kingfisher's existing processors; cancel images when their views leave the screen. Prefer `PlaylistAsyncImage` for artwork so playlist User-Agent/cache identity, downsampling, and view-lifetime cancellation remain consistent. Do not decode through `AsyncImage` when the project image pipeline already handles the request. Do not download a whole catalog of original-size art.

Movie and TV `/images` responses have optional `backdrops`, `posters`, and `logos`. A title logo is optional; always retain a readable text-title fallback. For a clear logo, rank usable transparent PNGs deterministically: requested UI language (`tr`), English (`en`), unlabelled (`null`), then other languages; within a language, prefer vote average, vote count, and a stable path tie-break. Treat this ranking as a product heuristic, not a TMDB guarantee. Filter by format supported by the current image pipeline. TMDB documents SVG originals as non-resizable and PNG logos as available in normal sizes; do not feed SVG into Kingfisher without a compatible SVG renderer.

Catalog search results do not include title logos. Do not add one TMDB detail request per card. The current app learns logo and backdrop paths from detail or images responses and shares them through `TMDBTitleLogoCache`, keyed by playlist, media type, and item ID. Each path index is bounded to 300 entries and persists only file paths; a missing logo entry means the card uses its text title until a response supplies a logo. Manual title overrides suppress the matched TMDB logo to avoid displaying art for a different title. A dashboard hero may resolve assets for the single currently presented featured item when the keyed logo has not been resolved: first require a normalized exact title match and honor the year when both sides provide one, then use the media-specific `/images` endpoint instead of fetching full detail subresources. Cache the returned logo and backdrop together. Never fan out detail or images requests across all dashboard or catalog cards.

Keep poster and backdrop artwork separate. Posters preserve a portrait crop; backdrops use a wide crop. Do not stretch landscape artwork into portrait cards or crop a title logo as if it were a poster. Give logos enough empty space, preserve aspect ratio, and keep metadata/actions legible when a logo is missing or fails to load.

For tvOS, use the Apple TV focus behavior already established in the design system: transparent focus surface, controlled scale, and clipping/insets that do not cut off enlarged artwork. Avoid introducing a bright outline or glow around media posters.

## TCA and concurrency

- Model network work as injected `@DependencyClient` operations and consume dependencies in reducers using the repository's current TCA pattern.
- Keep API effects cancellable and associate responses with the request or selected media identity so an old response cannot replace a newer selection.
- Decode and transform data off the main actor where supported by the existing `NetworkClient` and Swift concurrency model. Do not move image decoding or large catalog processing onto the UI thread.
- Keep DTOs `Codable`, `Equatable`, and `Sendable` where project conventions require it; model server-optional fields as optional.
- Cache only bounded, reusable metadata. Include playlist identity in keys when a title ID is provider-specific. Do not erase existing favorites, watch history, manual matches, or presentation overrides as part of cache changes.
- Use the repository's client test values. Do not add tests or run the test suite unless the user asks; a build or focused runtime validation may be used to verify implementation.

## IPTVX-inspired presentation

Use the official IPTVX 25 newsroom as a visual reference, not as a source to copy assets or proprietary implementation. Its stated Apple TV direction puts title artwork and cinematic backdrop first, groups facts compactly, gives Play/Resume a clear primary action, and leaves personal actions and supporting sections separate. Search cards use landscape VOD artwork and title logos when available; series pages group seasons and episodes clearly. Adapt these ideas to PureIPTV's existing navigation, data, focus behavior, localization, and access rules.

## TMDB attribution

For applicable non-commercial API use, TMDB requires source attribution and its notice: “This product uses the TMDB API but is not endorsed or certified by TMDB.” The notice belongs in an About/Credits area, and an approved TMDB brand logo should be less prominent than the app's own identity. Do not imply endorsement. Confirm licensing requirements with TMDB before commercial use; this skill does not grant image or data rights.

## Delivery checklist

1. State which endpoint(s), query parameters, and DTO fields changed.
2. Verify logo language/format fallback and the text fallback.
3. Verify the display size, downsampling, playlist-aware cache identity, and cancellation behavior for changed artwork. Give hero/button content finite width constraints when embedding remote logo images in flexible layouts.
4. Preserve manual match and saved user data behavior.
5. Build the affected Apple platform target and report warnings or blockers accurately. Only claim visual verification after viewing the running screen.
