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
}
