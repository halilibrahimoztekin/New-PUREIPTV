import ComposableArchitecture
import SwiftUI

// MARK: - Catchup & Timeshift Timeline Scrubber View (Feature #4)

/// Interactive Visual Scrubber & Timeline Bookmarks for IPTV Catchup / Timeshift TV Archive.
/// Fully compatible with Apple TV 10-foot UI (Siri Remote Focus Engine) and iOS Touch / Gestures.
public struct CatchupTimelineScrubberView: View {
    public let store: StoreOf<PlayerFeature>
    public let onClose: () -> Void

    @State private var selectedDayOffset: Int = 0 // 0 = Bugün, 1 = Dün, 2 = 2 Gün Önce
    #if os(tvOS)
        @FocusState private var focusedProgramID: String?
        @FocusState private var focusedDayOffset: Int?
        @FocusState private var isCloseFocused: Bool
        @FocusState private var isReturnToLiveFocused: Bool
    #endif

    public init(store: StoreOf<PlayerFeature>, onClose: @escaping () -> Void) {
        self.store = store
        self.onClose = onClose
    }

    private var calendar: Calendar {
        Calendar.current
    }

    private var filteredPrograms: [EPGProgram] {
        let targetDate = calendar.date(byAdding: .day, value: -selectedDayOffset, to: Date()) ?? Date()
        let targetStart = calendar.startOfDay(for: targetDate)
        guard let targetEnd = calendar.date(byAdding: .day, value: 1, to: targetStart) else {
            return store.epgListings
        }

        let filtered = store.epgListings.filter { prog in
            prog.startTime >= targetStart && prog.startTime < targetEnd
        }.sorted { $0.startTime < $1.startTime }

        return filtered.isEmpty ? store.epgListings : filtered
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Header Bar & Days Filter
            headerBar

            catchupOffsetControls

            // Day Selector Tabs
            dayFilterTabs

            // Interactive Horizontal Bookmarks Ribbon
            programBookmarksRibbon

            // Return to Live Stream Quick Action (if currently watching catchup)
            if store.isPlayingCatchup {
                returnToLiveBar
            }
        }
        #if os(tvOS)
        .padding(28)
        .frame(maxWidth: 1120)
        .background(
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Color(hex: "#0C0C10").opacity(0.94)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: "#BF5AF2").opacity(0.6), Color(hex: "#0A84FF").opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: .black.opacity(0.7), radius: 30, x: 0, y: 15)
        .focusSection()
        .onExitCommand {
            onClose()
        }
        #else
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Color(hex: "#0C0C10").opacity(0.96)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: "#BF5AF2").opacity(0.5), Color.white.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .shadow(color: .black.opacity(0.65), radius: 24, x: 0, y: 10)
        #endif
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#BF5AF2").opacity(0.2))
                    .frame(width: 36, height: 36)
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(hex: "#BF5AF2"))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(AppStrings.Player.catchupTimelineTitle)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    CatchUpBadge(isCompact: true)
                }

                Text(store.item.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer()

            Button {
                #if !os(tvOS)
                    HapticManager.shared.trigger(.light)
                #endif
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            #if os(tvOS)
                .focused($isCloseFocused)
            #endif
        }
    }

    // MARK: - Day Filter Tabs

    private var dayFilterTabs: some View {
        HStack(spacing: 8) {
            dayTabButton(title: AppStrings.Player.today, offset: 0)
            dayTabButton(title: AppStrings.Player.yesterday, offset: 1)
            dayTabButton(title: AppStrings.Player.twoDaysAgo, offset: 2)

            Spacer()
        }
    }

    private var catchupOffsetControls: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Arşiv saat düzeltmesi".localized)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Yalnızca bu kanalın catch-up başlangıç saatini değiştirir.".localized)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Button {
                store.send(.setCatchupTimeShiftHours(store.catchupTimeShiftHours - 1))
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
            }
            .accessibilityLabel("Arşiv saatini bir saat geri al".localized)

            Text(String(format: "%+d sa", store.catchupTimeShiftHours))
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .frame(minWidth: 56)
                .accessibilityLabel("Arşiv düzeltmesi %@".localized(String(format: "%+d saat", store.catchupTimeShiftHours)))

            Button {
                store.send(.setCatchupTimeShiftHours(store.catchupTimeShiftHours + 1))
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
            }
            .accessibilityLabel("Arşiv saatini bir saat ileri al".localized)
        }
        .foregroundStyle(Color(hex: "#BF5AF2"))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func dayTabButton(title: String, offset: Int) -> some View {
        let isSelected = selectedDayOffset == offset
        #if os(tvOS)
            let isFocused = focusedDayOffset == offset
        #else
            let isFocused = false
        #endif

        Button {
            #if !os(tvOS)
                HapticManager.shared.trigger(.light)
            #endif
            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                selectedDayOffset = offset
            }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: (isSelected || isFocused) ? .bold : .medium))
                .foregroundColor((isSelected || isFocused) ? .white : .white.opacity(0.6))
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(
                    isFocused
                        ? Color(hex: "#BF5AF2")
                        : (isSelected ? Color(hex: "#BF5AF2").opacity(0.35) : Color.white.opacity(0.08)),
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isFocused
                                ? Color.white
                                : (isSelected ? Color(hex: "#BF5AF2").opacity(0.7) : Color.clear),
                            lineWidth: isFocused ? 2 : 1
                        )
                )
        }
        .buttonStyle(.plain)
        #if os(tvOS)
            .focused($focusedDayOffset, equals: offset)
            .scaleEffect(isFocused ? 1.08 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isFocused)
        #endif
    }

    // MARK: - Program Bookmarks Ribbon

    private var programBookmarksRibbon: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                if filteredPrograms.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "tv.slash")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.3))
                        Text(AppStrings.Player.epgNotFound)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .frame(width: 320, height: 140)
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
                } else {
                    ForEach(filteredPrograms) { program in
                        programBookmarkCard(program: program)
                    }
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 2)
        }
    }

    @ViewBuilder
    private func programBookmarkCard(program: EPGProgram) -> some View {
        let isCurrentArchive = store.activeCatchupProgram?.id == program.id
        let isLiveNow = program.isPlayingNow
        let durationMinutes = max(1, Int(program.endTime.timeIntervalSince(program.startTime) / 60))

        Button {
            #if !os(tvOS)
                HapticManager.shared.trigger(.medium)
            #endif
            if isLiveNow {
                store.send(.returnToLiveStream)
            } else {
                store.send(.playArchive(program))
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                // Time & Status Header
                HStack(spacing: 6) {
                    Text("\(formatTime(program.startTime)) - \(formatTime(program.endTime))")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(isLiveNow ? Color(hex: "#00F5D4") : (isCurrentArchive ? Color(hex: "#BF5AF2") : .white.opacity(0.65)))

                    Spacer()

                    if isLiveNow {
                        HStack(spacing: 4) {
                            Circle().fill(Color.red).frame(width: 5, height: 5)
                            Text("CANLI")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.18), in: Capsule())
                    } else if isCurrentArchive {
                        HStack(spacing: 4) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 9))
                            Text("OYNATILIYOR")
                                .font(.system(size: 9, weight: .heavy))
                        }
                        .foregroundColor(Color(hex: "#BF5AF2"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "#BF5AF2").opacity(0.2), in: Capsule())
                    } else {
                        Text("\(durationMinutes) dk")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.45))
                    }
                }

                // Program Title
                Text(program.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Description Preview
                if !program.description.isEmpty {
                    Text(program.description)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                // Action Callout / Bookmark Indicator
                HStack {
                    if isLiveNow {
                        Label(AppStrings.Player.jumpToNow, systemImage: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(hex: "#00F5D4"))
                    } else {
                        Label(AppStrings.Player.watchCatchUp, systemImage: "arrow.counterclockwise")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(isCurrentArchive ? Color(hex: "#BF5AF2") : Color(hex: "#64D2FF"))
                    }
                    Spacer()
                }
            }
            .padding(12)
            .frame(width: 250, height: 130)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        isCurrentArchive
                            ? Color(hex: "#BF5AF2").opacity(0.2)
                            : (isLiveNow ? Color(hex: "#00F5D4").opacity(0.12) : Color.white.opacity(0.06))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isCurrentArchive
                            ? Color(hex: "#BF5AF2").opacity(0.7)
                            : (isLiveNow ? Color(hex: "#00F5D4").opacity(0.5) : Color.white.opacity(0.1)),
                        lineWidth: isCurrentArchive ? 1.8 : 1.0
                    )
            )
        }
        .buttonStyle(.plain)
        #if os(tvOS)
            .focused($focusedProgramID, equals: program.id)
            .scaleEffect(focusedProgramID == program.id ? 1.05 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: focusedProgramID)
        #endif
    }

    // MARK: - Return to Live Bar

    private var returnToLiveBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Circle().fill(Color.purple).frame(width: 8, height: 8)
                Text(AppStrings.Player.playingArchiveBanner)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }

            Spacer()

            Button {
                #if !os(tvOS)
                    HapticManager.shared.trigger(.medium)
                #endif
                store.send(.returnToLiveStream)
            } label: {
                HStack(spacing: 6) {
                    Circle().fill(Color.red).frame(width: 7, height: 7)
                    Text(AppStrings.Player.returnToLive)
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color.red.opacity(0.85), in: Capsule())
                .shadow(color: Color.red.opacity(0.4), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            #if os(tvOS)
                .focused($isReturnToLiveFocused)
            #endif
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
