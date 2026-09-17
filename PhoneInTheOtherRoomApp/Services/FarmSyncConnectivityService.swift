import Foundation
#if canImport(Network)
import Network
#endif

/// Reports an offline-to-online transition without tying Farm persistence to a
/// view lifecycle. Tests use `reportPath(satisfied:)` with monitoring disabled.
@MainActor
final class FarmSyncConnectivityService {
    var onRecovery: (() -> Void)?
    private var lastSatisfied: Bool?
#if canImport(Network)
    private let monitor: NWPathMonitor?
    private let queue = DispatchQueue(label: "com.countingsheep.farm-sync-connectivity")
#endif

    init(startMonitoring: Bool = true) {
#if canImport(Network)
        guard startMonitoring else { monitor = nil; return }
        let monitor = NWPathMonitor()
        self.monitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in self?.reportPath(satisfied: path.status == .satisfied) }
        }
        monitor.start(queue: queue)
#endif
    }

    deinit {
#if canImport(Network)
        monitor?.cancel()
#endif
    }

    func reportPath(satisfied: Bool) {
        defer { lastSatisfied = satisfied }
        guard lastSatisfied == false, satisfied else { return }
        onRecovery?()
    }
}
