//
//  LiquidGlassComponents.swift
//  PureIPTV
//
//  Created for PureIPTV Cinematic Obsidian Design System.
//  Implements native Apple Liquid Glass (iOS 26+, tvOS 26+, macOS 26+)
//  with seamless obsidian glassmorphic fallbacks on earlier OS versions.
//

import SwiftUI

// MARK: - Liquid Glass Shape

/// Supported geometric shapes for Liquid Glass surfaces.
public enum LiquidGlassShape: Sendable, Hashable {
    case capsule
    case roundedRectangle(cornerRadius: CGFloat)
    case circle

    public static func rect(cornerRadius: CGFloat) -> LiquidGlassShape {
        .roundedRectangle(cornerRadius: cornerRadius)
    }
}

// MARK: - Liquid Glass Container

/// A multi-element container that merges overlapping glass surfaces on iOS/tvOS 26+
/// using Apple's `GlassEffectContainer`, while providing clean layout grouping on earlier OS.
public struct LiquidGlassContainer<Content: View>: View {
    public let spacing: CGFloat?
    public let content: Content

    public init(spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        if #available(iOS 26, tvOS 26, macOS 26, *) {
            if let spacing {
                GlassEffectContainer(spacing: spacing) {
                    content
                }
            } else {
                GlassEffectContainer {
                    content
                }
            }
        } else {
            content
        }
    }
}

// MARK: - Liquid Glass View Modifier

/// Unifying modifier that applies native `.glassEffect()` on iOS/tvOS 26+ and
/// pixel-perfect Obsidian glassmorphic styling with continuous squircle corners,
/// ultra-thin material, and subtle rim light on earlier OS versions.
public struct LiquidGlassModifier: ViewModifier {
    public let shape: LiquidGlassShape
    public let tint: Color?
    public let isInteractive: Bool
    public let surfaceColor: Color

    public init(
        shape: LiquidGlassShape = .capsule,
        tint: Color? = nil,
        isInteractive: Bool = false,
        surfaceColor: Color = AppColors.surfaceSecondary
    ) {
        self.shape = shape
        self.tint = tint
        self.isInteractive = isInteractive
        self.surfaceColor = surfaceColor
    }

    public func body(content: Content) -> some View {
        if #available(iOS 26, tvOS 26, macOS 26, *) {
            let effect: Glass = {
                var e = Glass.regular
                if let tint {
                    e = e.tint(tint)
                }
                if isInteractive {
                    e = e.interactive()
                }
                return e
            }()
            switch shape {
            case .capsule:
                content.glassEffect(effect, in: .capsule)
            case let .roundedRectangle(radius):
                content.glassEffect(effect, in: .rect(cornerRadius: radius))
            case .circle:
                content.glassEffect(effect, in: .circle)
            }
        } else {
            obsidianFallback(content: content)
        }
    }

    @ViewBuilder
    private func obsidianFallback(content: Content) -> some View {
        switch shape {
        case .capsule:
            content
                .background {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Capsule().fill(surfaceColor.opacity(0.85))
                        }
                        .overlay {
                            if let tint {
                                Capsule().fill(tint.opacity(0.15))
                            }
                        }
                }
                .overlay {
                    Capsule()
                        .stroke(AppColors.borderSubtle, lineWidth: 1)
                }

        case let .roundedRectangle(radius):
            content
                .background {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .fill(surfaceColor.opacity(0.85))
                        }
                        .overlay {
                            if let tint {
                                RoundedRectangle(cornerRadius: radius, style: .continuous)
                                    .fill(tint.opacity(0.15))
                            }
                        }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(AppColors.borderSubtle, lineWidth: 1)
                }

        case .circle:
            content
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Circle().fill(surfaceColor.opacity(0.85))
                        }
                        .overlay {
                            if let tint {
                                Circle().fill(tint.opacity(0.15))
                            }
                        }
                }
                .overlay {
                    Circle()
                        .stroke(AppColors.borderSubtle, lineWidth: 1)
                }
        }
    }
}

// MARK: - View Extension for Liquid Glass

public extension View {
    /// Applies the Liquid Glass effect with native Apple APIs on iOS/tvOS 26+ and Obsidian fallback on earlier OS.
    func liquidGlass(
        shape: LiquidGlassShape = .capsule,
        tint: Color? = nil,
        isInteractive: Bool = false,
        surfaceColor: Color = AppColors.surfaceSecondary
    ) -> some View {
        modifier(LiquidGlassModifier(
            shape: shape,
            tint: tint,
            isInteractive: isInteractive,
            surfaceColor: surfaceColor
        ))
    }

    /// Alias for `.liquidGlass(...)` complying with task.md naming.
    func liquidGlassEffect(
        shape: LiquidGlassShape = .capsule,
        tint: Color? = nil,
        isInteractive: Bool = false,
        surfaceColor: Color = AppColors.surfaceSecondary
    ) -> some View {
        liquidGlass(
            shape: shape,
            tint: tint,
            isInteractive: isInteractive,
            surfaceColor: surfaceColor
        )
    }

    /// Morphing animation identifier supporting `.glassEffectID` on iOS 26+ and matched geometry on earlier OS.
    @ViewBuilder
    func liquidGlassID(_ id: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 26, tvOS 26, macOS 26, *) {
            glassEffectID(id, in: namespace)
        } else {
            matchedGeometryEffect(id: id, in: namespace)
        }
    }
}

// MARK: - Liquid Glass Pill (Tags, Category Chips & Status Badges)

/// Interactive pill for category chips, filter tags, and status badges.
/// Fully responsive across iOS, iPadOS, macOS, and tvOS with focus engine scaling.
public struct LiquidGlassPill: View {
    public let title: String
    public let icon: String?
    public let isSelected: Bool
    public let badgeCount: Int?
    public let badgeText: String?
    public let tint: Color?
    public let onTap: (@MainActor () -> Void)?

    public init(
        title: String,
        icon: String? = nil,
        isSelected: Bool = false,
        badgeCount: Int? = nil,
        badgeText: String? = nil,
        tint: Color? = nil,
        onTap: (@MainActor () -> Void)? = nil
    ) {
        self.title = title
        self.icon = icon
        self.isSelected = isSelected
        self.badgeCount = badgeCount
        self.badgeText = badgeText
        self.tint = tint
        self.onTap = onTap
    }

    public var body: some View {
        if let onTap {
            Button(action: onTap) {
                pillLabel
            }
            .buttonStyle(LiquidGlassPillButtonStyle(isSelected: isSelected, tint: tint))
        } else {
            pillLabel
                .liquidGlass(
                    shape: .capsule,
                    tint: isSelected ? (tint ?? AppColors.primary) : nil,
                    isInteractive: false
                )
        }
    }

    private var pillLabel: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(AppFonts.captionSemibold)
            }
            Text(title)
                .font(AppFonts.captionSemibold)
                .lineLimit(1)

            if let badgeText, !badgeText.isEmpty {
                Text(badgeText)
                    .font(AppFonts.captionSmall)
                    .foregroundStyle(isSelected ? AppColors.textPrimary : (tint ?? AppColors.primary))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.white.opacity(0.2) : (tint ?? AppColors.primary).opacity(0.18), in: Capsule())
            } else if let badgeCount, badgeCount > 0 {
                Text("\(badgeCount)")
                    .font(AppFonts.captionSmall)
                    .foregroundStyle(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.white.opacity(0.2) : AppColors.surfaceElevated, in: Capsule())
            }
        }
        .foregroundStyle(foregroundColor)
        #if os(tvOS)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        #else
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        #endif
    }

    private var foregroundColor: Color {
        if isSelected {
            AppColors.textPrimary
        } else {
            AppColors.textSecondary
        }
    }
}

// MARK: - Pill Button Style

private struct LiquidGlassPillButtonStyle: ButtonStyle {
    let isSelected: Bool
    let tint: Color?

    func makeBody(configuration: Configuration) -> some View {
        LiquidGlassPillButtonBody(configuration: configuration, isSelected: isSelected, tint: tint)
    }
}

private struct LiquidGlassPillButtonBody: View {
    let configuration: ButtonStyle.Configuration
    let isSelected: Bool
    let tint: Color?

    #if os(tvOS)
        @Environment(\.isFocused) private var isFocused
    #endif

    var body: some View {
        configuration.label
            .liquidGlass(
                shape: .capsule,
                tint: isSelected ? (tint ?? AppColors.primary) : nil,
                isInteractive: true
            )
        #if os(tvOS)
            .scaleEffect(isFocused ? 1.08 : (configuration.isPressed ? 0.96 : 1.0))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
            .overlay {
                if isFocused {
                    Capsule()
                        .stroke(tint ?? AppColors.primary, lineWidth: 3)
                        .padding(-2)
                }
            }
        #else
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
        #endif
    }
}

// MARK: - Liquid Glass Action Button

/// Reusable action button supporting primary, secondary, and destructive actions.
/// Adapts to `.buttonStyle(.glassProminent)` and `.buttonStyle(.glass)` on iOS/tvOS 26+,
/// and high-contrast obsidian styles on earlier OS versions.
public struct LiquidGlassActionButton: View {
    public enum Style: Sendable, Hashable {
        case primary
        case secondary
        case destructive
    }

    public let title: String
    public let icon: String?
    public let style: Style
    public let tint: Color?
    public let isLoading: Bool
    public let action: @MainActor () -> Void

    public init(
        _ title: String,
        icon: String? = nil,
        style: Style = .primary,
        tint: Color? = nil,
        isLoading: Bool = false,
        action: @escaping @MainActor () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.tint = tint
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        if #available(iOS 26, tvOS 26, macOS 26, *) {
            Button(action: action) {
                buttonLabel
            }
            .applyNativeGlassStyle(style: style, tint: tint)
            .disabled(isLoading)
        } else {
            Button(action: action) {
                buttonLabel
            }
            .buttonStyle(ObsidianActionButtonStyle(style: style, tint: tint))
            .disabled(isLoading)
        }
    }

    private var buttonLabel: some View {
        HStack(spacing: 8) {
            if isLoading {
                ProgressView()
                    .tint(style == .primary ? Color.white : (tint ?? AppColors.primary))
            } else if let icon {
                Image(systemName: icon)
                    .font(AppFonts.button)
            }
            Text(title)
                .font(AppFonts.button)
                .lineLimit(1)
        }
        #if os(tvOS)
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
        #else
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        #endif
    }
}

/// Typealias for `LiquidGlassActionButton` complying with task.md naming.
public typealias LiquidGlassButton = LiquidGlassActionButton

// MARK: - Native Glass Button Style Helper

@available(iOS 26, tvOS 26, macOS 26, *)
private extension View {
    @ViewBuilder
    func applyNativeGlassStyle(style: LiquidGlassActionButton.Style, tint: Color?) -> some View {
        switch style {
        case .primary:
            buttonStyle(.glassProminent)
                .tint(tint ?? AppColors.primary)
        case .secondary:
            buttonStyle(.glass)
                .tint(tint)
        case .destructive:
            buttonStyle(.glassProminent)
                .tint(tint ?? AppColors.destructive)
        }
    }
}

// MARK: - Obsidian Action Button Style (Fallback)

private struct ObsidianActionButtonStyle: ButtonStyle {
    let style: LiquidGlassActionButton.Style
    let tint: Color?

    func makeBody(configuration: Configuration) -> some View {
        ObsidianActionButtonBody(configuration: configuration, style: style, tint: tint)
    }
}

private struct ObsidianActionButtonBody: View {
    let configuration: ButtonStyle.Configuration
    let style: LiquidGlassActionButton.Style
    let tint: Color?

    #if os(tvOS)
        @Environment(\.isFocused) private var isFocused
    #endif

    var body: some View {
        configuration.label
            .background {
                backgroundView
            }
            .foregroundStyle(foregroundColor)
            .overlay {
                Capsule()
                    .stroke(borderStrokeColor, lineWidth: 1)
            }
        #if os(tvOS)
            .scaleEffect(isFocused ? 1.08 : (configuration.isPressed ? 0.96 : 1.0))
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isFocused)
            .overlay {
                if isFocused {
                    Capsule()
                        .stroke(focusStrokeColor, lineWidth: 3)
                        .padding(-2)
                }
            }
        #else
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
        #endif
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .primary:
            Capsule()
                .fill(tint ?? AppColors.primary)
        case .secondary:
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule().fill(AppColors.surfaceSecondary.opacity(0.85))
                }
        case .destructive:
            Capsule()
                .fill(tint ?? AppColors.destructive)
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary, .destructive:
            Color.white
        case .secondary:
            AppColors.textPrimary
        }
    }

    private var borderStrokeColor: Color {
        switch style {
        case .primary, .destructive:
            Color.white.opacity(0.2)
        case .secondary:
            AppColors.borderSubtle
        }
    }

    private var focusStrokeColor: Color {
        tint ?? (style == .destructive ? AppColors.destructive : AppColors.primary)
    }
}

// MARK: - Liquid Glass HUD Card

/// Floating modal or overlay surface for HUD overlays (EQ, Stream Health, OSD, Dialer).
/// Provides high-depth glassmorphic elevation with 1px rim light and continuous squircle corners.
public struct LiquidGlassHUDCard<Content: View>: View {
    public let cornerRadius: CGFloat
    public let tint: Color?
    public let isInteractive: Bool
    public let content: Content

    public init(
        cornerRadius: CGFloat = 16,
        tint: Color? = nil,
        isInteractive: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.tint = tint
        self.isInteractive = isInteractive
        self.content = content()
    }

    public var body: some View {
        content
            .liquidGlass(
                shape: .rect(cornerRadius: cornerRadius),
                tint: tint,
                isInteractive: isInteractive,
                surfaceColor: AppColors.surfaceSecondary
            )
            .shadow(color: Color.black.opacity(0.4), radius: 24, x: 0, y: 12)
    }
}

// MARK: - Liquid Glass Visual Effect Blur (Performance-Tuned UIKit Fallback)

#if os(iOS) || os(tvOS)
    import UIKit

    /// High-performance blur effect wrapper utilizing UIKit's `UIVisualEffectView`
    /// to eliminate SwiftUI shader compilation overhead on older OS versions.
    public struct LiquidGlassVisualEffectBlur: UIViewRepresentable {
        public let style: UIBlurEffect.Style

        #if os(tvOS)
            public init(style: UIBlurEffect.Style = .dark) {
                self.style = style
            }
        #else
            public init(style: UIBlurEffect.Style = .systemThinMaterialDark) {
                self.style = style
            }
        #endif

        public func makeUIView(context _: Context) -> UIVisualEffectView {
            let view = UIVisualEffectView(effect: UIBlurEffect(style: style))
            view.backgroundColor = .clear
            return view
        }

        public func updateUIView(_ uiView: UIVisualEffectView, context _: Context) {
            uiView.effect = UIBlurEffect(style: style)
        }
    }
#endif

// MARK: - Liquid Glass Segmented Picker

/// A fluid, glassmorphic segmented picker for categories, media types, and filter modes.
/// Merges items inside a `LiquidGlassContainer` with high-contrast active item pill.
public struct LiquidGlassSegmentedPicker<Item: Hashable & Identifiable, Content: View>: View {
    public let items: [Item]
    @Binding public var selection: Item
    public let content: (Item, Bool) -> Content

    @Namespace private var pickerNamespace

    public init(
        items: [Item],
        selection: Binding<Item>,
        @ViewBuilder content: @escaping (Item, Bool) -> Content
    ) {
        self.items = items
        _selection = selection
        self.content = content
    }

    public var body: some View {
        LiquidGlassContainer(spacing: 4) {
            HStack(spacing: 4) {
                ForEach(items) { item in
                    let isSelected = item == selection
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            selection = item
                        }
                    } label: {
                        content(item, isSelected)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background {
                                if isSelected {
                                    Capsule()
                                        .fill(AppColors.primary)
                                        .matchedGeometryEffect(id: "activePickerPill", in: pickerNamespace)
                                } else {
                                    Capsule()
                                        .fill(Color.clear)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(isSelected ? AppColors.textPrimary : AppColors.onSurfaceVariant)
                }
            }
            .padding(4)
            .liquidGlass(shape: .capsule, surfaceColor: AppColors.surfaceContainer)
        }
    }
}

// MARK: - Liquid Glass Floating Overlay

/// Universal dismissable overlay container for Player HUDs, quick actions, and detail popovers.
public struct LiquidGlassFloatingOverlay<OverlayContent: View>: ViewModifier {
    @Binding public var isPresented: Bool
    public let alignment: Alignment
    public let onDismiss: (() -> Void)?
    public let overlayContent: () -> OverlayContent

    public init(
        isPresented: Binding<Bool>,
        alignment: Alignment = .center,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder overlayContent: @escaping () -> OverlayContent
    ) {
        _isPresented = isPresented
        self.alignment = alignment
        self.onDismiss = onDismiss
        self.overlayContent = overlayContent
    }

    public func body(content: Content) -> some View {
        ZStack(alignment: alignment) {
            content

            if isPresented {
                AppColors.background.opacity(0.55)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            isPresented = false
                            onDismiss?()
                        }
                    }

                overlayContent()
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.94).combined(with: .opacity),
                        removal: .scale(scale: 0.96).combined(with: .opacity)
                    ))
                    .zIndex(100)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isPresented)
    }
}

public extension View {
    /// Presents a dismissable modal/HUD floating overlay wrapped in Liquid Glass aesthetics.
    func liquidGlassFloatingOverlay(
        isPresented: Binding<Bool>,
        alignment: Alignment = .center,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> some View
    ) -> some View {
        modifier(LiquidGlassFloatingOverlay(
            isPresented: isPresented,
            alignment: alignment,
            onDismiss: onDismiss,
            overlayContent: content
        ))
    }
}
