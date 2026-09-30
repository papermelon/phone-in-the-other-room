import Foundation

enum SlumberPartyLink {
    static let host = "countingsheepproject.com"
    static let pendingCodeKey = "ollie.slumberParty.pendingLinkCode"
    static func code(in url: URL) -> String? {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.user == nil, parts.password == nil, parts.port == nil, parts.query == nil, parts.fragment == nil else { return nil }
        let path: String
        if parts.scheme?.lowercased() == "https", [host, "www.countingsheepproject.com"].contains(parts.host?.lowercased() ?? "") {
            guard parts.path.hasPrefix("/invite/") else { return nil }
            path = String(parts.path.dropFirst("/invite/".count))
        } else if parts.scheme == "countingsheep", parts.host == "invite" {
            path = String(parts.path.dropFirst())
        } else { return nil }
        let value = path.uppercased()
        guard value.count == NightFlockInviteCode.length, value.allSatisfy({ NightFlockInviteCode.alphabet.contains($0) }) else { return nil }
        return value
    }
    static func url(code: String) -> URL? {
        guard code.count == NightFlockInviteCode.length, code.allSatisfy({ NightFlockInviteCode.alphabet.contains($0) }) else { return nil }
        return URL(string: "https://\(host)/invite/\(code)")
    }
}
