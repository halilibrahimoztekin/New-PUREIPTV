import SwiftUI

public struct MediaLanguageFilterBar: View {
    public let availableFilters: [MediaLanguageFilter]
    public let selectedFilter: MediaLanguageFilter
    public let counts: [MediaLanguageFilter: Int]
    public let onSelect: (MediaLanguageFilter) -> Void

    public init(
        availableFilters: [MediaLanguageFilter],
        selectedFilter: MediaLanguageFilter,
        counts: [MediaLanguageFilter: Int],
        onSelect: @escaping (MediaLanguageFilter) -> Void
    ) {
        self.availableFilters = availableFilters
        self.selectedFilter = selectedFilter
        self.counts = counts
        self.onSelect = onSelect
    }

    public var body: some View {
        // Only render if more than just the .all filter is present
        if availableFilters.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(availableFilters, id: \.self) { filter in
                        let isSelected = selectedFilter == filter
                        let count = counts[filter] ?? 0

                        Button {
                            #if os(iOS)
                                HapticManager.shared.trigger(.light)
                            #endif
                            onSelect(filter)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: filter.iconName)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(isSelected ? filter.tintColor : Color.white.opacity(0.6))

                                Text(filter.title)
                                    .font(.system(size: 12.5, weight: isSelected ? .bold : .medium))

                                if count > 0 {
                                    Text("\(count)")
                                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1.5)
                                        .background(
                                            isSelected
                                                ? filter.tintColor.opacity(0.25)
                                                : Color.white.opacity(0.08),
                                            in: Capsule()
                                        )
                                        .foregroundColor(isSelected ? filter.tintColor : Color.white.opacity(0.7))
                                }
                            }
                            .foregroundColor(isSelected ? .white : Color.white.opacity(0.75))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                isSelected
                                    ? AnyShapeStyle(
                                        LinearGradient(
                                            colors: [Color(hex: "#1F2333"), Color(hex: "#161824")],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    : AnyShapeStyle(Color.black.opacity(0.35))
                            )
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(
                                        isSelected
                                            ? filter.tintColor.opacity(0.8)
                                            : Color.white.opacity(0.1),
                                        lineWidth: isSelected ? 1.4 : 1
                                    )
                            )
                            .shadow(
                                color: isSelected ? filter.tintColor.opacity(0.25) : .clear,
                                radius: 4, y: 1
                            )
                        }
                        #if os(tvOS)
                        .buttonStyle(TVCapsuleButtonStyle(isPrimary: false, isSelected: isSelected))
                        #else
                        .buttonStyle(.plain)
                        #endif
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
        }
    }
}
