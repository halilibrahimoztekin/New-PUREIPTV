import SwiftUI

public struct OriginalLanguageFilterBar: View {
    public let availableCodes: [String]
    public let selectedCode: String?
    public let counts: [String: Int]
    public let onSelect: (String?) -> Void

    public init(
        availableCodes: [String],
        selectedCode: String?,
        counts: [String: Int],
        onSelect: @escaping (String?) -> Void
    ) {
        self.availableCodes = availableCodes
        self.selectedCode = selectedCode
        self.counts = counts
        self.onSelect = onSelect
    }

    public var body: some View {
        if !availableCodes.isEmpty || selectedCode != nil {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterButton(code: nil, title: AppStrings.MediaFilter.all, count: counts["all"])
                    ForEach(availableCodes, id: \.self) { code in
                        let title = Locale.current.localizedString(forLanguageCode: code)?.capitalized ?? code.uppercased()
                        filterButton(code: code, title: title, count: counts[code])
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
            .accessibilityLabel(AppStrings.Player.originalLanguageFilter)
            .accessibilityHint(AppStrings.Player.originalLanguageUnknownHint)
        }
    }

    private func filterButton(code: String?, title: String, count: Int?) -> some View {
        let hasUnavailableSelection = selectedCode.map { !availableCodes.contains($0) } ?? false
        let isSelected = selectedCode == code || (code == nil && hasUnavailableSelection)
        return Button {
            #if os(iOS)
                HapticManager.shared.trigger(.light)
            #endif
            onSelect(code)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: code == nil ? "square.stack.3d.up" : "globe")
                    .font(.system(size: 11, weight: .semibold))
                Text(title).font(.system(size: 12.5, weight: isSelected ? .bold : .medium))
                if let count {
                    Text("\(count)")
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                }
            }
            .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.75))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color(hex: "#26314A") : Color.black.opacity(0.35), in: Capsule())
            .overlay(Capsule().stroke(isSelected ? Color.accentColor : Color.white.opacity(0.12), lineWidth: 1))
        }
        #if os(tvOS)
        .buttonStyle(TVCapsuleButtonStyle(isPrimary: false, isSelected: isSelected))
        #else
        .buttonStyle(.plain)
        #endif
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
