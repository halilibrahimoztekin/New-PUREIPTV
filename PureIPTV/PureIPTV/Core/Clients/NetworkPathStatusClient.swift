import ComposableArchitecture
import Dispatch
import Foundation
import Network

private actor NetworkPathCostMonitor {
    static let shared = NetworkPathCostMonitor()

    private let monitor: NWPathMonitor
    private var currentValue: Bool?
    private var waiters: [CheckedContinuation<Bool, Never>] = []

    private init() {
        let monitor = NWPathMonitor()
        self.monitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            let isConstrainedOrExpensive = path.isConstrained || path.isExpensive
            Task {
                await self?.update(isConstrainedOrExpensive: isConstrainedOrExpensive)
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.pureiptv.network-path-cost", qos: .utility))
    }

    func currentPathIsConstrainedOrExpensive() async -> Bool {
        if let currentValue {
            return currentValue
        }

        return await withCheckedContinuation { continuation in
            if let currentValue {
                continuation.resume(returning: currentValue)
            } else {
                waiters.append(continuation)
            }
        }
    }

    private func update(isConstrainedOrExpensive: Bool) {
        currentValue = isConstrainedOrExpensive
        let pendingWaiters = waiters
        waiters.removeAll(keepingCapacity: true)
        for waiter in pendingWaiters {
            waiter.resume(returning: isConstrainedOrExpensive)
        }
    }
}

public struct NetworkPathStatusClient: Sendable {
    public var currentPathIsConstrainedOrExpensive: @Sendable () async -> Bool

    public init(currentPathIsConstrainedOrExpensive: @escaping @Sendable () async -> Bool) {
        self.currentPathIsConstrainedOrExpensive = currentPathIsConstrainedOrExpensive
    }
}

extension NetworkPathStatusClient: DependencyKey {
    public static let liveValue = NetworkPathStatusClient {
        await NetworkPathCostMonitor.shared.currentPathIsConstrainedOrExpensive()
    }

    public static let testValue = NetworkPathStatusClient {
        false
    }
}

public extension DependencyValues {
    var networkPathStatusClient: NetworkPathStatusClient {
        get { self[NetworkPathStatusClient.self] }
        set { self[NetworkPathStatusClient.self] = newValue }
    }
}
