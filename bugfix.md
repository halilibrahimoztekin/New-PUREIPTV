# PureIPTV Bugfix & Stabilization Report

This document records all identified issues, their root causes, and the exact architectural fixes implemented in the PureIPTV tvOS codebase.

---

### Bug 1: Stack Overflow Crash on tvOS (`AppCoordinator.core`)
- **Severity:** Critical (App Crash on Launch / First Action)
- **Symptom:** Fatal crash `EXC_BAD_ACCESS (code=2, address=0x16d713ff8)` at `___chkstk_darwin` inside `AppCoordinator.core(state:inout State, action: Action)`.
- **Root Cause:** The monolithic 7,000+ line reducer in `AppCoordinator.swift` contained nested pattern matching, dozens of large state mutations, and local scope variables. LLVM compiler inlined and coalesced these into a single stack frame exceeding the default stack limit allocated to tvOS threads.
- **Fix:** Decoupled `AppCoordinator.core` into modular, domain-specific reducer methods (`reduceRouteAction`, `reduceLifecycleAndHandoff`, `reducePlayerEvents`, `reduceSettingsActions`, etc.) annotated with `@inline(never)` to prevent compiler stack coalescing.

---

### Bug 2: Missing Key-Value Storage (KVS) Entitlement
- **Severity:** High (Console Failure / CloudSync Failure)
- **Symptom:** `BUG IN CLIENT OF KVS: Trying to initialize NSUbiquitousKeyValueStore without a store identifier. Please specify your store identifier in the 'com.apple.developer.ubiquity-kvstore-identifier' entitlement.`
- **Root Cause:** `NSUbiquitousKeyValueStore` was initialized for iCloud preferences synchronization without declaring the requisite entitlement in the Xcode target.
- **Fix:** Added `com.apple.developer.ubiquity-kvstore-identifier` set to `$(TeamIdentifierPrefix)$(CFBundleIdentifier)` in `PureIPTV.entitlements`.

---

### Bug 3: Aggressive Paywall Interruptions
- **Severity:** High (Hostile UX / App Store Guideline 3.1.2)
- **Symptom:** The premium subscription paywall popped up repeatedly on every launch, during tab changes, and blocked users from even viewing movie or series details.
- **Root Cause:** `subscriptionStatusResponse` in `AppCoordinator.swift` unconditionally dispatched `.presentPaywall` whenever `isPremium == false` or on network error. In addition, catalog navigation delegates (`didSelectVOD`, `didSelectSeries`) intercepted clicks and presented the paywall before users could browse content info.
- **Fix:**
  1. Overhauled `subscriptionStatusResponse` to present the initial promotional paywall **ONLY ONCE** upon first entry, guarded by `UserDefaults` (`com.pureiptv.hasShownInitialPaywallPromo`).
  2. Removed paywall gates from catalog item browsing (`didSelectVOD`, `didSelectSeries`), allowing users to browse posters, summaries, cast, and episode lists freely.
  3. Enforced an **Action-Based Paywall**: Only prompted with upgrade requirements when the user explicitly triggers playback (`didSelectPlay` in `VODDetail`, `didSelectEpisode` in `SeriesDetail`, and history playback).

---

### Bug 4: Non-Existent AVPlayer Playback Option in Settings & OSD
- **Severity:** Medium (Broken Feature / User Confusion)
- **Symptom:** Settings and Player OSD menus showed an "AVPlayer" option, but IPTV stream playback with AVPlayer failed or was unsupported.
- **Root Cause:** Legacy placeholder UI for AVPlayer selection remained after migrating playback to SwiftVLC with hardware acceleration.
- **Fix:** Standardized playback strictly on SwiftVLC. Removed AVPlayer selection rows, settings toggles, and OSD options across `SettingsView`, `SettingsFeature`, and `PlayerView+tvOS`.

---

### Bug 5: Competitor Brand Mentions
- **Severity:** Medium (Branding / App Store Review Risk)
- **Symptom:** Mentions of third-party competitor "TiviMate" were present in network headers and user-agent configurations.
- **Root Cause:** Hardcoded user-agent string copied from third-party client templates.
- **Fix:** Sanitized `UserAgentManager.swift` to remove all competitor names and replace them with clean, neutral media player user agents.

---

### Bug 6: Unsupported Trakt.tv Integration
- **Severity:** Medium (Dead Code & Error Spams)
- **Symptom:** Trakt.tv scrobbling and watchlist synchronization resulted in network errors and scrobble failure HUD toasts because backend infrastructure was absent.
- **Root Cause:** Incomplete third-party Trakt integration scattered throughout `PlayerFeature`, `SettingsFeature`, and `AppCoordinator`.
- **Fix:** Completely excised Trakt.tv:
  - Deleted `PureIPTV/Features/Trakt/`, `TraktScrobbleHUDView.swift`, `TraktClient.swift`, `TraktModels.swift`, and `TraktMediaParser.swift`.
  - Removed all Trakt actions, scrobble handlers, and `@Dependency(\.traktClient)` from `PlayerFeature.swift`, `SettingsFeature.swift`, and `AppCoordinator.swift`.

---

### Bug 7: Video Player Controls Focus Loss & Cramped Layout on tvOS
- **Severity:** High (Broken Siri Remote Navigation / Poor UX)
- **Symptom:** Transport controls were compressed inside a horizontal `ScrollView`, causing focus to get lost or trapped. Buttons were tiny and unintuitive on the Siri Remote.
- **Root Cause:** Improper layout container (`ScrollView`) for tvOS 10-foot UI, missing `@FocusState` bindings, and lack of a default focus anchor.
- **Fix:** Redesigned `VideoControllerView` in `PlayerView+tvOS.swift` according to the Cinematic Obsidian design system:
  - Eliminated the horizontal `ScrollView` in favor of a fixed-width, spacious `HStack`.
  - Added dedicated focus fields in `FocusableField` (`restart`, `backward`, `replayWithSubtitles`, `playPause`, `forward`, `skipMarkers`, `liveChannelsMenu`, `audioSubtitleMenu`, `displayModeMenu`).
  - Added `.defaultFocus($focusableField, .playPause)` and `.focusSection()` so Siri Remote focus naturally lands on Play/Pause and navigates smoothly.

---

### Bug 8: Series Playback Resume Failure in Continue Watching
- **Severity:** Medium (Playback Broken)
- **Symptom:** Selecting a previously watched series episode from "Continue Watching" failed to play or started from the wrong position.
- **Root Cause:** In `AppCoordinator.swift` (`playHistoryItem`), fallback stream URL construction for series episodes failed when username/password credentials were missing or improperly extracted from the playlist config.
- **Fix:** Ensured stream URL resolution uses the active playlist's credentials and correctly passes the episode extension and resume timestamp to `PlayerFeature`.

---

### Bug 9: False VLC Aspect Ratio / Screen Size Error Toast
- **Severity:** Low (Annoying Error Banner)
- **Symptom:** An 8-second toast complaining "VLC cannot provide display criteria" was presented whenever a video started.
- **Root Cause:** `DisplayModeClient` returned `.criteriaUnavailable` when VLC handled rendering directly without AVPlayer match criteria, which `PlayerFeature` mistakenly treated as an error toast condition.
- **Fix:** Filtered out `.criteriaUnavailable` and `.systemMatchingDisabled` in `PlayerFeature.swift`, suppressing false error banners.

---

### Bug 10: Player State High-Frequency Update Overhead
- **Severity:** Medium (CPU Spikes & UI Stutter)
- **Symptom:** Player controls and progress bar caused UI micro-stutters and high CPU usage during active playback.
- **Root Cause:** SwiftVLC player emitted `timeChanged` and `positionChanged` updates up to 60 times per second, triggering heavy TCA state derivations on every frame.
- **Fix:**
  - Throttled `.timeChanged`: mutations are skipped if the elapsed whole second has not changed.
  - Throttled `.positionChanged`: mutations are skipped if the position delta is less than 0.5% (`0.005`).

---

### Bug 11: Outdated Test Suite Signatures & Missing `@CasePathable`
- **Severity:** Medium (CI / Test Target Compilation Failure)
- **Symptom:** Test build failed in `PlaylistManagementFeatureTests`, `CustomEPGMappingEngineTests`, `ParentalControlEngineTests`, `TopShelfEngineTests`, and `LiveEPGPreviewEngineTests`.
- **Root Cause:**
  - `PlaylistManagementFeature.closeAddPlaylistTapped` required `requestID: UUID`.
  - `CustomEPGMappingClient.applyTimeShift` required `playlistID: UUID?`.
  - `ParentalControlClient` had additional closure parameters not supplied by memberwise init in tests.
  - `EPGGuideFeature.Action` lacked `@CasePathable`, breaking key-path matching in test stores.
- **Fix:**
  - Added `@Dependency(\.uuid)` in `PlaylistManagementFeature` and updated tests with deterministic UUIDs.
  - Provided `playlistID: nil` in `CustomEPGMappingEngineTests`.
  - Switched `ParentalControlEngineTests` to mutate test client closures on default instance.
  - Added `@CasePathable` to `EPGGuideFeature.Action` and fixed `fetchShortEPG` mock argument count.
  - Built comprehensive mock snapshot tests with realistic content in `ViewSnapshotTests.swift`.

---

### Bug 12: Non-Deterministic Dynamic Mesh Colors Causing Snapshot Test Inconsistency
- **Severity:** Low (Test Inconsistency & Rendering Jitter)
- **Symptom:** `DynamicMeshBackgroundView` generated slightly different colors on consecutive process launches for the same seed title.
- **Root Cause:** In `DynamicMeshBackgroundView.swift`, `fromSeed(_ seed: String)` computed color hues using `seed.hashValue`. In the Swift standard library, `String.hashValue` uses SipHash with a randomized seed initialized per-process, preventing deterministic snapshot testing.
- **Fix:** Replaced `seed.hashValue` with a deterministic djb2 hash algorithm:
  ```swift
  let hash = abs(seed.utf8.reduce(5381) { (($0 << 5) &+ $0) &+ Int($1) })
  ```
  ensuring true color stability across all simulator launches and snapshot runs.

---

### Bug 13: Massive Memory Layout Stack Overflow in TCA Reducer Chain (`___chkstk_darwin`)
- **Severity:** Critical (Fatal Launch / Action Dispatch Crash on Apple TV)
- **Symptom:** `Thread 1: EXC_BAD_ACCESS (code=2, address=0x16d713ff8)` in `___chkstk_darwin` at `AppCoordinator.swift:267` inside `Reduce<State, Action> { state, action in core(state: &state, action: action) }`.
- **Root Cause:**
  - Measurement using `MemoryLayout` revealed enormous enum sizes: `AppCoordinator.Action` was **2,000 bytes**, `AppScreen.Action` was **1,992 bytes**, and `HomeFeature.Action` was **1,987 bytes**.
  - During TCA action dispatch, the call stack traverses 23 nested reducer closures (`RootCore._send`, `withDependencies`, `_IfLetReducer`, `Reduce._reduce`, `AppCoordinator.core`).
  - Because these enums were value types copied onto the stack at every frame, each dispatch required over ~46 KB of stack space just for action copies.
  - On tvOS, thread stack limits (typically 512 KB on cooperative thread pools or secondary threads) were exceeded, causing `___chkstk_darwin` to probe past the stack guard page into forbidden memory (`KERN_PROTECTION_FAILURE`).
- **Fix:**
  - Converted `AppScreen` from an enum to `public indirect enum AppScreen`.
  - Converted `AppCoordinator.Action`, `HomeFeature.Action`, `PlayerFeature.Action`, `SeriesDetailFeature.Action`, and `VODDetailFeature.Action` into `indirect enum Action`.
  - This boxes enum payloads onto the heap, reducing their stack footprint from **2,000 bytes down to an 8-byte pointer** (a 99.6% reduction in stack usage per frame), permanently eliminating the stack overflow crash.

---

### Bug 14: Comprehensive tvOS 10-Foot UI/UX & Focus Engine Overhaul
- **Severity:** High (Broken Focus / Inconsistent 10-Foot Legibility)
- **Symptom:** Elements lacked 3D parallax focus elevation; buttons relied on iOS touch-based `.fluidScale` or flat `.tvFocusEffect()`; text sizes (11-15pt) were illegible from 3 meters away; safe margins were too tight (48-60pt), risking overscan clipping on physical TVs.
- **Root Cause:** Views were ported from iOS without complete tvOS design system adaptations. Compound cards wrapped only subviews in `Button`, breaking focus on adjacent text.
- **Fix:**
  - **Button Styles & 3D Parallax:** Replaced `.fluidScale` and flat modifiers with `TVGridCardButtonStyle(cornerRadius: 16)` (with 1.08x focus scale, glowing shadow, and 0.96x press-down depression), `TVCapsuleButtonStyle`, and `TVCircleButtonStyle`.
  - **Typography Scaling:** Scaled titles to 20-24pt semibold/bold, metadata to 15-18pt, and badges to 14-16pt across `VODCardView`, `SeriesCardView`, `ChannelCardView`, `ResumeWatchingCardView`, `EpisodeCardView`, `NextUpEpisodeBannerView`, and `CategoryManagementView`.
  - **Overscan Margins:** Standardized on 80px safe margins (`.padding(.horizontal, 80)`) across `SearchView+tvOS`, `DownloadsView+tvOS`, `DashboardView+tvOS`, and detail screens.
  - **Compound Card Focus:** Restructured `TVProfileCard` so the button bounds encompass both avatar and title label, ensuring unified 3D parallax scaling and focus feedback.
  - **Paywall Redesign:** Overhauled `PaywallView+tvOS` with Cinematic Obsidian radial gradient, 52pt heavy title, 340x260 glassmorphic packages with `TVGridCardButtonStyle(cornerRadius: 20)`, and `TVCapsuleButtonStyle` actions.

---

### Bug 16: Video Player Controller Auto-Hide Interruption During Active Navigation
- **Severity:** High (Broken User Experience / Remote Frustration)
- **Symptom:** When attempting to adjust audio tracks, switch subtitles, or inspect options from the video player controller on Apple TV, the controller abruptly closed after 5 seconds, cutting off user navigation midway.
- **Root Cause:**
  1. The idle countdown timer was hardcoded to 5.0 seconds and only reset upon initial mask appearance or click events.
  2. tvOS Siri Remote directional focus transitions (`@FocusState private var focusableField`) were not monitored, meaning moving focus between buttons failed to reset the countdown timer.
  3. Scrubber dragging/seeking (`isScrubbing`) was stored locally in `VideoTimeShowView` without propagation to `keepsControllerVisibleWhileOpen`, allowing the overlay to dismiss while scrubbing.
  4. Transport buttons (`restart`, `jumpBackward`, `replayWithSubtitles`, `jumpForward`) were missing `.focused($focusedField, equals: ...)` bindings.
- **Fix:**
  - Extended baseline timeout from 5.0s to 9.0s (`resetIdleTimer(duration: 9.0)`).
  - Added `.onChange(of: focusableField)` to reset and extend the countdown timer on every focus transition across controller elements.
  - Bound `.focused($focusedField, equals: ...)` to all transport buttons.
  - Bound `@State private var isScrubbing` from `PlayerView_tvOS` into `VideoTimeShowView` and added it to `keepsControllerVisibleWhileOpen`.

---

### Bug 17: Filterable Structured Video Player Observability & Logging Subsystem
- **Severity:** Medium (Diagnostics & Error Reporting)
- **Symptom:** Developers and QA had no centralized, filterable log output to diagnose VLC playback errors, stream stalls, auto-reconnect backoffs, or track switching issues in Xcode Console or Terminal.
- **Root Cause:** Scattered `print` statements without unified category tags, level severity, or sensitive credential redaction.
- **Fix:**
  - Implemented `PlayerLogger.swift` utilizing `os.Logger(subsystem: "com.pureiptv.app", category: "VideoPlayer")` combined with structured standard output.
  - Formatted each entry with high-visibility filterable prefix: `HH:mm:ss.SSS [PureIPTV:Player] 🔴 [ERROR] [VLC] <message>`.
  - Added instant filtering capability in Xcode Console filter bar via `[PureIPTV:Player]`, `[ERROR]`, `[WARN]`, `[STREAM]`, `[VLC]`, or `[RECONNECT]`.
  - Built-in regex sanitization that automatically redacts Xtream passwords, user credentials, and authentication tokens from stream URLs and query strings.
  - Integrated hooks across `PlayerFeature.swift` and `PlayerClient.swift` covering stream start, VLC state transitions, buffer watchdog stalls, auto-reconnects, and audio/subtitle selection.


