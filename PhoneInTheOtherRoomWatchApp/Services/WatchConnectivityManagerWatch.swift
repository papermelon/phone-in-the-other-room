import Foundation
import OSLog
import WatchConnectivity

final class WatchConnectivityManagerWatch: NSObject, ObservableObject {
    static let shared = WatchConnectivityManagerWatch()

    @Published private(set) var isReachable = false
    var onMessage: ((WatchMessage) -> Void)?
#if DEBUG
    private let energyLogger = Logger(
        subsystem: "com.ngawangchime.countingsheep",
        category: "Energy.WatchConnectivity.Watch"
    )
    private var debugSendCount = 0
    private var debugLastSendAt: Date?
#endif

    override private init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(_ message: WatchMessage) {
        guard WCSession.isSupported() else { return }
        let dictionary = WatchMessageCodec.dictionary(from: message)
#if DEBUG
        logSend(message)
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

    func sendWithReply(_ message: WatchMessage, replyHandler: @escaping (WatchMessage?) -> Void) {
        guard WCSession.isSupported() else {
            replyHandler(nil)
            return
        }
        let dictionary = WatchMessageCodec.dictionary(from: message)
#if DEBUG
        logSend(message)
#endif
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(dictionary) { reply in
                DispatchQueue.main.async {
                    replyHandler(WatchMessageCodec.message(from: reply))
                }
            } errorHandler: { _ in
                WCSession.default.transferUserInfo(dictionary)
                DispatchQueue.main.async { replyHandler(nil) }
            }
        } else {
            WCSession.default.transferUserInfo(dictionary)
            replyHandler(nil)
        }
    }

    private func shouldQueueWhenUnreachable(_ type: WatchMessageType) -> Bool {
        switch type {
        case .pingPhone, .pingWatch, .endFocusRunEarly:
            return true
        default:
            return false
        }
    }

#if DEBUG
    private func logSend(_ message: WatchMessage) {
        debugSendCount += 1
        let now = Date()
        let interval = debugLastSendAt.map { now.timeIntervalSince($0) } ?? 0
        debugLastSendAt = now
        let shouldLog = message.type != .watchDistanceReading
            || debugSendCount <= 3
            || debugSendCount.isMultiple(of: 10)
        guard shouldLog else { return }
        energyLogger.debug(
            "send count=\(self.debugSendCount) type=\(message.type.rawValue, privacy: .public) secondsSincePrevious=\(interval, format: .fixed(precision: 3)) reachable=\(WCSession.default.isReachable)"
        )
    }
#endif
}

extension WatchConnectivityManagerWatch: WCSessionDelegate {
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

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let decoded = WatchMessageCodec.message(from: applicationContext) else { return }
        DispatchQueue.main.async { self.onMessage?(decoded) }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let decoded = WatchMessageCodec.message(from: userInfo) else { return }
        DispatchQueue.main.async { self.onMessage?(decoded) }
    }
}
