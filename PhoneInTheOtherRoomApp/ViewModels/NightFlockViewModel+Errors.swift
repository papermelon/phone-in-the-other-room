import Foundation
import Supabase

extension NightFlockViewModel {
    static func phase(for error: Error) -> Phase {
        var detail = error.localizedDescription
        if let functionsError = error as? FunctionsError {
            switch functionsError {
            case .relayError:
                return .offline
            case .httpError(let code, let data):
                if code >= 500 { return .offline }
                if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let serverDetail = (object["error"] as? String) ?? (object["message"] as? String) {
                    detail = serverDetail
                }
            }
        }
        let message = detail.lowercased()
        if message.contains("invite") && message.contains("expired") { return .expiredInvite }
        if message.contains("full") || message.contains("capacity") { return .fullFlock }
        if message.contains("blocked") { return .blocked }
        if error is URLError { return .offline }
        return .error(detail)
    }
}
