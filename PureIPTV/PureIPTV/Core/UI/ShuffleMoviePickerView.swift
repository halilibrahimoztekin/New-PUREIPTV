import SwiftUI

public struct ShuffleMoviePickerView: View {
    public let allVODs: [MediaModels.Item]
    public let onSelectMovie: (MediaModels.Item) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var currentMovie: MediaModels.Item?
    @State private var isRolling: Bool = false
    @State private var rotationAngle: Double = 0.0

    public init(allVODs: [MediaModels.Item], onSelectMovie: @escaping (MediaModels.Item) -> Void) {
        self.allVODs = allVODs
        self.onSelectMovie = onSelectMovie
    }

    public var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ne İzlesem? (Rastgele Film)")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("IMDb 7.0+ ve yüksek puanlı filmlerden öneriler")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Movie Presentation Card
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(white: 0.14))
                    .frame(height: 280)

                if let movie = currentMovie {
                    HStack(spacing: 18) {
                        // Poster
                        if let coverURL = movie.coverURL {
                            AsyncImage(url: coverURL) { phase in
                                switch phase {
                                case let .success(image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 140, height: 210)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .shadow(radius: 8)
                                default:
                                    fallbackPoster(title: movie.title)
                                }
                            }
                        } else {
                            fallbackPoster(title: movie.title)
                        }

                        // Details
                        VStack(alignment: .leading, spacing: 10) {
                            Text(movie.title)
                                .font(.title3.bold())
                                .foregroundStyle(.white)
                                .lineLimit(2)

                            if let rating = movie.rating, rating > 0 {
                                HStack(spacing: 6) {
                                    Image(systemName: "star.fill")
                                        .foregroundStyle(.yellow)
                                        .font(.caption)
                                    Text(String(format: "%.1f", rating))
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.white)
                                    Text("IMDb")
                                        .font(.caption2.bold())
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.yellow.opacity(0.15))
                                .clipShape(Capsule())
                            }

                            if !movie.categoryID.isEmpty {
                                Text(movie.categoryID)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                onSelectMovie(movie)
                                dismiss()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "play.fill")
                                    Text("Hemen İzle")
                                        .fontWeight(.semibold)
                                }
                                .font(.subheadline)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 20)

                        Spacer()
                    }
                    .padding(16)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "dice.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.cyan)
                            .rotationEffect(.degrees(rotationAngle))

                        Text("Zarları Atmak İçin Dokun")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Shuffle Action Button
            Button {
                rollRandomMovie()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "shuffle")
                        .rotationEffect(.degrees(rotationAngle))
                    Text(isRolling ? "Film Seçiliyor..." : "Rastgele Film Çevir")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: Color.purple.opacity(0.4), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(isRolling)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(white: 0.10).opacity(0.98))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .frame(maxWidth: 460)
        .onAppear {
            rollRandomMovie()
        }
    }

    private func rollRandomMovie() {
        guard !allVODs.isEmpty else { return }
        isRolling = true

        #if os(iOS)
            HapticManager.shared.trigger(.medium)
        #endif

        withAnimation(.easeInOut(duration: 0.5)) {
            rotationAngle += 360
        }

        // Filter high rating candidates (>= 7.0), or fallback to all
        let highRated = allVODs.filter { ($0.rating ?? 0) >= 7.0 }
        let pool = !highRated.isEmpty ? highRated : allVODs

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                currentMovie = pool.randomElement()
                isRolling = false
            }
            #if os(iOS)
                HapticManager.shared.trigger(.success)
            #endif
        }
    }

    private func fallbackPoster(title: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 140, height: 210)

            VStack(spacing: 8) {
                Image(systemName: "film")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 6)
            }
        }
    }
}
