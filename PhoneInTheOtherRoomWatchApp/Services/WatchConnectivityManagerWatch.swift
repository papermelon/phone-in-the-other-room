import Foundation
import WatchConnectivity

final class WatchConnectivityManagerWatch: NSObject, ObservableObject {
    static let shared = WatchConnectivityManagerWatch()

    @Published private(set) var isReachable = false
    var onMessage: ((WatchMessage) -> Void)?

    override private init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(_ message: WatchMessage) {
        guard WCSession.isSupported() else { return }
        let dictionary = WatchMessageCodec.dictionary(from: message)
        try? WCSession.default.updateApplicationContext(dictionary)
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(dictionary, replyHandler: nil) { _ in
                WCSession.default.transferUserInfo(dictionary)
            }
        } else if message.type == .pingPhone || message.type == .pingWatch || message.type == .endFocusRunEarly {
            WCSession.default.transferUserInfo(dictionary)
        }
    }

    func sendWithReply(_ message: WatchMessage, replyHandler: @escaping (WatchMessage?) -> Void) {
        guard WCSession.isSupported() else {
            replyHandler(nil)
            return
        }
        let dictionary = WatchMessageCodec.dictionary(from: message)
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
