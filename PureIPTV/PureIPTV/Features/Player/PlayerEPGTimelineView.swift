import Combine
import ComposableArchitecture
import SwiftUI

public struct PlayerEPGTimelineView: View {
    let programs: [EPGProgram]
    let currentPosition: Double
    let onClose: () -> Void
    let onSelect: (EPGProgram) -> Void

    @State private var currentTime = Date()
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    public init(programs: [EPGProgram], currentPosition: Double, onClose: @escaping () -> Void, onSelect: @escaping (EPGProgram) -> Void) {
        self.programs = programs
        self.currentPosition = currentPosition
        self.onClose = onClose
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppStrings.Player.epg)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(AppStrings.Player.timeline)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                Button(action: {
                    onClose()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.7))
                }
                #if os(tvOS)
                .buttonStyle(TVCircleButtonStyle())
                #else
                .buttonStyle(.plain)
                #endif
            }
            .padding(16)
            .background(Color.black.opacity(0.4))

            Divider().background(Color.white.opacity(0.2))

            // Timeline
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    if programs.isEmpty {
                        Text(AppStrings.Player.epgNotFound)
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.horizontal, 40)
                    } else {
                        ForEach(programs) { program in
                            Button(action: {
                                onSelect(program)
                            }) {
                                PlayerEPGTimelineCard(program: program, currentTime: currentTime)
                            }
                            #if os(tvOS)
                            .buttonStyle(.card)
                            #else
                            .buttonStyle(.plain)
                            #endif
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(AnyShapeStyle(.ultraThinMaterial))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .onReceive(timer) { time in
            currentTime = time
        }
    }
}

public struct PlayerEPGTimelineCard: View {
    let program: EPGProgram
    let currentTime: Date

    private var progress: Double {
        let total = program.endTime.timeIntervalSince(program.startTime)
        let elapsed = currentTime.timeIntervalSince(program.startTime)
        if total > 0 {
            return max(0, min(1, elapsed / total))
        }
        return 0
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(formatTime(program.startTime)) - \(formatTime(program.endTime))")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(program.isPlayingNow ? .white : .white.opacity(0.7))

                Spacer()

                if program.isPlayingNow {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                            .symbolEffect(.pulse)
                        Text(AppStrings.Player.liveLabelNormal)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.2))
                    .clipShape(Capsule())
                }
            }

            Text(program.title)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            if !program.description.isEmpty {
                Text(program.description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)

            if program.isPlayingNow {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 4)

                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: geo.size.width * CGFloat(progress), height: 4)
                    }
                }
                .frame(height: 4)
                .padding(.top, 4)
            }
        }
        .padding(12)
        .frame(width: 240, height: 130)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(program.isPlayingNow ? Color.accentColor.opacity(0.2) : Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(program.isPlayingNow ? Color.accentColor.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
