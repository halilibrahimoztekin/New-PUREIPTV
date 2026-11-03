//
//  LiquidGlassTests.swift
//  PureIPTVTests
//
//  Unit tests verifying Liquid Glass components and modifier configurations.
//

@testable import PureIPTV
import SwiftUI
import XCTest

final class LiquidGlassTests: XCTestCase {
    func testLiquidGlassShapeCreation() {
        let capsule = LiquidGlassShape.capsule
        let rect = LiquidGlassShape.rect(cornerRadius: 16)
        let circle = LiquidGlassShape.circle

        XCTAssertEqual(capsule, .capsule)
        XCTAssertEqual(rect, .roundedRectangle(cornerRadius: 16))
        XCTAssertEqual(circle, .circle)
    }

    func testLiquidGlassPillProperties() {
        let pill = LiquidGlassPill(
            title: "Sports",
            icon: "sportscourt",
            isSelected: true,
            badgeCount: 5,
            badgeText: "HD",
            tint: AppColors.primary
        )

        XCTAssertEqual(pill.title, "Sports")
        XCTAssertEqual(pill.icon, "sportscourt")
        XCTAssertTrue(pill.isSelected)
        XCTAssertEqual(pill.badgeCount, 5)
        XCTAssertEqual(pill.badgeText, "HD")
        XCTAssertEqual(pill.tint, AppColors.primary)
    }

    func testLiquidGlassActionButtonProperties() {
        let button = LiquidGlassActionButton(
            "Watch Now",
            icon: "play.fill",
            style: .primary,
            tint: AppColors.primary
        ) {}

        XCTAssertEqual(button.title, "Watch Now")
        XCTAssertEqual(button.icon, "play.fill")
        XCTAssertEqual(button.style, .primary)
        XCTAssertEqual(button.tint, AppColors.primary)
    }

    func testLiquidGlassHUDCardInitialization() {
        let card = LiquidGlassHUDCard(cornerRadius: 24, tint: AppColors.accent, isInteractive: true) {
            Text("HUD Card Test")
        }

        XCTAssertEqual(card.cornerRadius, 24)
        XCTAssertEqual(card.tint, AppColors.accent)
        XCTAssertTrue(card.isInteractive)
    }

    struct MockItem: Identifiable, Hashable {
        let id: String
        let title: String
    }

    func testLiquidGlassSegmentedPicker() {
        let items = [
            MockItem(id: "all", title: "Tümü"),
            MockItem(id: "live", title: "Canlı TV"),
        ]
        var selectedItem = items[0]
        let binding = Binding<MockItem>(
            get: { selectedItem },
            set: { selectedItem = $0 }
        )

        let picker = LiquidGlassSegmentedPicker(items: items, selection: binding) { item, _ in
            Text(item.title)
        }

        XCTAssertEqual(picker.items.count, 2)
        XCTAssertEqual(picker.items.first?.id, "all")
    }

    #if os(iOS) || os(tvOS)
        func testLiquidGlassVisualEffectBlur() {
            let blur = LiquidGlassVisualEffectBlur(style: .dark)
            XCTAssertEqual(blur.style, .dark)
        }
    #endif
}
