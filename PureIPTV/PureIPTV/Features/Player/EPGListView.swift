import ComposableArchitecture
import SwiftUI

public struct EPGListView: View {
    let programs: [EPGProgram]
    let currentPosition: Double
    let onClose: () -> Void

    public init(programs: [EPGProgram], currentPosition: Double, onClose: @escaping () -> Void) {
        self.programs = programs
        self.currentPosition = currentPosition
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(AppStrings.Player.epg)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button(action: {
                    onClose()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Color.black.opacity(0.6))

            Divider().background(Color.white.opacity(0.2))

            // List
            ScrollView {
                LazyVStack(spacing: 12) {
                    if programs.isEmpty {
                        Text(AppStrings.Player.epgNotFound)
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.top, 40)
                    } else {
                        ForEach(programs) { program in
                            EPGProgramRow(program: program)
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(AnyShapeStyle(.ultraThinMaterial))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

public struct EPGProgramRow: View {
    let program: EPGProgram

    public init(program: EPGProgram) {
        self.program = program
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(formatTime(program.startTime))
                    .font(.subheadline)
                    .fontWeight(program.isPlayingNow ? .bold : .regular)
                    .foregroundColor(program.isPlayingNow ? .accentColor : .white.opacity(0.7))
                Text(formatTime(program.endTime))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(width: 50, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(program.title)
                    .font(.subheadline)
                    .fontWeight(program.isPlayingNow ? .bold : .regular)
                    .foregroundColor(program.isPlayingNow ? .accentColor : .white)
                    .lineLimit(2)

                if !program.description.isEmpty {
                    Text(program.description)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(3)
                }
            }
            Spacer()

            if program.isPlayingNow {
                Text(AppStrings.Player.nowPlaying)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.2))
                    .foregroundColor(.accentColor)
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
