# PureIPTV Design System: Cinematic Obsidian

This document defines the core visual language, colors, typography, layout, and component rules for the PureIPTV app across iOS, iPadOS, macOS, and tvOS. The design system focuses on a premium, high-end entertainment experience utilizing OLED blacks and "Cinematic Glassmorphism".

## Brand & Style

The design system is engineered for a premium, high-end entertainment experience across the Apple ecosystem. It targets a sophisticated audience that values cinematic immersion and technical precision. The style is **Cinematic Glassmorphism**. It utilizes deep OLED blacks to provide infinite contrast for content posters, while employing frosted glass layers and vibrant blurs to create a sense of physical depth. 

## Colors
The palette is optimized for OLED displays and low-light viewing environments.

- **Background (OLED Black):** `#000000` or `#131317` (True Black is the foundation, ensuring hardware bezels disappear).
- **Surfaces (Anthracite):** `#0C0C10` or `#1F1F23` (Secondary containers and cards for subtle separation from true black).
- **Primary Accent (Electric Blue):** `#0A84FF` (Primary action color, high legibility).
- **Premium Accent (Neon Purple):** `#BF5AF2` (Reserved for premium features and discovery highlights).
- **Status (Live Red):** `#FF453A` (Used exclusively for "Live" badges and critical alerts).
- **Text & Icons:** 
  - On-Surface: `#E4E1E7`
  - On-Surface-Variant: `#C0C6D6`

## Typography
*Note: While original mockups used Inter, this native Swift app uses Apple's native **SF Pro** for maximum performance, optical sizing, and legibility.*

- **Display Large (TV/iPad):** 48px, Heavy (800), line-height: 56px, letter-spacing: -0.02em.
- **Display Large (Mobile):** 34px, Heavy (800), line-height: 40px, letter-spacing: -0.01em.
- **Headline (md):** 24px, Bold (700).
- **Title (sm):** 20px, Semibold (600).
- **Body (lg):** 17px, Regular (400) - Standard reading size.
- **Body (sm):** 15px, Regular (400).
- **Label (Caps):** 12px, Bold (700), All-Caps, increased tracking (0.05em). Used for metadata ("4K", "HDR", "LIVE").
- **tvOS Scaling:** For the 10-foot interface, typography scales by 1.5x to 2x. 

## Layout & Spacing
- **Margins/Gutters:**
  - **Mobile:** 16px.
  - **iPad/Mac:** 32px (allows sidebars to breathe).
  - **tvOS:** 80px safe area. Generous gutters to prevent overlap when focused items scale up.
- **Vertical Rhythm:** 4px/8px base unit. 
  - Stack Small: 8px
  - Stack Medium: 16px
  - Stack Large: 32px

## Elevation & Depth (Glassmorphism)
Hierarchy is established through **vibrancy and blur** rather than traditional drop shadows.

- **Level 0 (Base):** OLED Black background.
- **Level 1 (Navigation/Plates):** Glassmorphic materials. Use `UltraThinMaterial` or `ThinMaterial` in SwiftUI.
- **Level 2 (Modals/Overlays):** Increased transparency with a primary color "rim light" (a 1px inner stroke) to define edges against the dark background.
- **Gradients:** Content rows use a linear bottom-to-top black gradient overlay for text legibility over poster art.

## Shapes
- **Continuous Curve (Squircle):** Native Apple rounded corners (`RoundedRectangle(cornerRadius: style: .continuous)`).
- **Content Cards:** 16px radius.
- **Buttons:** Fully rounded (pill-shaped) for primary actions.
- **tvOS Selection:** Focus halos match the 16px radius of the card with a 4px offset.

## Components
- **Vertical Posters (2:3):** Movies and Series. Must include a subtle 1px inner border (`.stroke(Color.white.opacity(0.1), lineWidth: 1)`) to prevent bleeding.
- **Horizontal Cards (16:9):** Live TV. Features a bottom-aligned progress bar using Electric Blue.
- **Live Indicator:** Small pill-shaped chip with `#FF453A` background and pulsing animation.
- **Navigation:**
  - **iOS:** Standard tab bar with high-vibrancy glass effect.
  - **iPad/Mac:** Permanent or collapsible sidebar with a thin vertical separator (white 10%).
  - **tvOS:** Floating top menu or tab view that hides during active playback.
- **Buttons:** 
  - Primary: Solid Electric Blue.
  - Secondary: "Ghost" style with glassmorphic background and white text.
- **Focus States (tvOS):** Scale up (1.1x) and gain a subtle outer glow using primary/secondary colors.
