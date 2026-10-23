import Dependencies
import Foundation
import RevenueCat
import RevenueCatUI

public struct PurchasesClient {
    public var configure: @Sendable (String) -> Void
    public var fetchOfferings: @Sendable () async throws -> RevenueCat.Offerings
    public var purchasePackage: @Sendable (RevenueCat.Package) async throws -> RevenueCat.CustomerInfo
    public var customerInfo: @Sendable () async throws -> RevenueCat.CustomerInfo
    public var restorePurchases: @Sendable () async throws -> RevenueCat.CustomerInfo
}

extension PurchasesClient: DependencyKey {
    public static var liveValue: PurchasesClient = .init(
        configure: { apiKey in
            Purchases.logLevel = .debug
            Purchases.configure(withAPIKey: apiKey)
        },
        fetchOfferings: {
            try await Purchases.shared.offerings()
        },
        purchasePackage: { package in
            let result = try await Purchases.shared.purchase(package: package)
            return result.customerInfo
        },
        customerInfo: {
            try await Purchases.shared.customerInfo()
        },
        restorePurchases: {
            try await Purchases.shared.restorePurchases()
        }
    )

    public static var testValue: PurchasesClient = .init(
        configure: { _ in },
        fetchOfferings: { throw URLError(.badURL) },
        purchasePackage: { _ in throw URLError(.badURL) },
        customerInfo: { throw URLError(.badURL) },
        restorePurchases: { throw URLError(.badURL) }
    )
}

public extension DependencyValues {
    var purchases: PurchasesClient {
        get { self[PurchasesClient.self] }
        set { self[PurchasesClient.self] = newValue }
    }
}
