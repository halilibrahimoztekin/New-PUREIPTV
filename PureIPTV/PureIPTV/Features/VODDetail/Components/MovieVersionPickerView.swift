import SwiftUI

/// Horizontal pill picker for switching between available quality and edition versions of a movie (Madde #47).
public struct MovieVersionPickerView: View {
    public let versions: [MovieVersionEdition]
    public let selectedVersionId: String
    public let onSelectVersion: (MovieVersionEdition) -> Void

    @FocusState private var focusedVersionId: String?

    public init(
        versions: [MovieVersionEdition],
        selectedVersionId: String,
        onSelectVersion: @escaping (MovieVersionEdition) -> Void
    ) {
        self.versions = versions
        self.selectedVersionId = selectedVersionId
        self.onSelectVersion = onSelectVersion
    }

    public var body: some View {
        guard versions.count > 1 else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.accentColor)

                    Text(AppStrings.VODDetail.versionsAndQuality)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("(\(versions.count))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)

                // Version Pills Scroll
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(versions) { version in
                            MovieVersionPillView(
                                version: version,
                                isSelected: version.id == selectedVersionId,
                                isFocused: focusedVersionId == version.id,
                                onSelect: {
                                    #if !os(tvOS)
                                        HapticManager.shared.trigger(.light)
                                    #endif
                                    onSelectVersion(version)
                                }
                            )
                            .focused($focusedVersionId, equals: version.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
            }
        )
    }
}

private struct MovieVersionPillView: View {
    let version: MovieVersionEdition
    let isSelected: Bool
    let isFocused: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                // Quality Badge
                Text(version.qualityLabel)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(isSelected ? .black : Color.accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        isSelected ? Color.white : Color.accentColor.opacity(0.18),
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                    )

                // Edition Text
                if version.editionLabel != "Standart" {
                    Text(version.editionLabel)
                        .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                        .foregroundColor(.white)
                }

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(backgroundView)
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.accentColor.opacity(0.6) : Color.white.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isFocused ? 1.08 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isFocused)
    }

    @ViewBuilder
    private var backgroundView: some View {
        if isSelected {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor, Color(hex: "#0A84FF")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        } else {
            Capsule()
                .fill(Color.white.opacity(0.08))
        }
    }
}
