import Foundation
import OSLog
import WatchConnectivity

final class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    @Published private(set) var isReachable = false
    var onMessage: ((WatchMessage) -> Void)?
    var currentStateProvider: (() -> WatchMessage?)?
    private var latestStateMessage: WatchMessage?
#if DEBUG
    private let energyLogger = Logger(
        subsystem: "com.ngawangchime.countingsheep",
        category: "Energy.WatchConnectivity.Phone"
    )
    private var debugSendCount = 0
    private var debugLastSendAt: Date?
#endif

    private init(activatesSession: Bool = true) {
        super.init()
        guard activatesSession else { return }
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

#if DEBUG
    static func inactiveForDeterministicCapture() -> WatchConnectivityManager {
        WatchConnectivityManager(activatesSession: false)
    }
#endif

    func send(_ message: WatchMessage) {
        guard WCSession.isSupported() else { return }
        if message.run != nil || message.proximity != nil || message.reward != nil {
            latestStateMessage = message
        }
        let dictionary = WatchMessageCodec.dictionary(from: message)
#if DEBUG
        debugSendCount += 1
        let now = Date()
        let interval = debugLastSendAt.map { now.timeIntervalSince($0) } ?? 0
        debugLastSendAt = now
        energyLogger.debug(
            "send count=\(self.debugSendCount) type=\(message.type.rawValue, privacy: .public) secondsSincePrevious=\(interval, format: .fixed(precision: 3)) reachable=\(WCSession.default.isReachable)"
        )
#endif
        try? WCSession.default.updateApplicationContext(dictionary)
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(dictionary, replyHandler: nil) { _ in
                WCSession.default.transferUserInfo(dictionary)
            }
        } else if shouldQueueWhenUnreachable(message.type) {
            WCSession.default.transferUserInfo(dictionary)
        }
    }

    private func shouldQueueWhenUnreachable(_ type: WatchMessageType) -> Bool {
        switch type {
        case .startFocusRun, .pingPhone, .pingWatch, .endFocusRunEarly:
            return true
        default:
            return false
        }
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { self.isReachable = session.isReachable }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { self.isReachable = session.isReachable }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let decoded = WatchMessageCodec.message(from: message) else { return }
        DispatchQueue.main.async { self.onMessage?(decoded) }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard let decoded = WatchMessageCodec.message(from: message) else {
            replyHandler([:])
            return
        }
        DispatchQueue.main.async {
            self.onMessage?(decoded)
            switch decoded.type {
            case .pingWatch:
                let response = self.currentStateProvider?() ?? self.latestStateMessage
                replyHandler(response.map(WatchMessageCodec.dictionary(from:)) ?? [:])
            case .pingPhone:
                let response = WatchMessage(type: .pingPhone)
                replyHandler(WatchMessageCodec.dictionary(from: response))
            default:
                replyHandler([:])
            }
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let decoded = WatchMessageCodec.message(from: applicationContext) else { return }
        DispatchQueue.main.async { self.onMessage?(decoded) }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let decoded = WatchMessageCodec.message(from: userInfo) else { return }
        DispatchQueue.main.async { self.onMessage?(decoded) }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
}
