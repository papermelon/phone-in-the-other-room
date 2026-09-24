import Foundation

struct AccountCredentialProfile: Equatable {
    var id: UUID
    var email: String?
    var username: String?
    var hasApple: Bool
    var hasEmail: Bool
    var usernameLookupSucceeded = true

    var signInMethodsTitle: String {
        if hasApple && hasEmail { return "Apple and email connected" }
        if hasApple { return "Apple connected" }
        if hasEmail { return "Email connected" }
        return "Sign-in method unavailable"
    }
}

/// Distinguishes the system sheet from account verification and Farm loading.
/// Support codes contain no credential, email, token, or Apple user identifier.
struct AppleAccountFailure: Equatable {
    enum Stage: String { case authorization, credential, account, farm }
    let stage: Stage
    var code: Int? = nil

    var message: String {
        switch stage {
        case .authorization: return "Apple couldn’t finish signing in. Please try again."
        case .credential: return "Apple didn’t return a sign-in credential. Please try again."
        case .account: return "Apple responded, but your account couldn’t be connected. Please try again."
        case .farm: return "Apple sign-in finished. Your Farm still needs to connect."
        }
    }

    var supportDetail: String {
        "Apple sign-in · \(stage.rawValue)" + (code.map { " · code \($0)" } ?? "")
    }
}

enum AccountCredentialError: LocalizedError {
    case invalidUsername, usernameUnavailable, usernameAlreadyClaimed, invalidCredentials, verifyEmail, unavailable, differentAccount
    var errorDescription: String? {
        switch self {
        case .invalidUsername: return "Use 3–24 letters, numbers or underscores, starting with a letter."
        case .usernameUnavailable: return "That handle is already taken. Choose another."
        case .usernameAlreadyClaimed: return "This account already has a handle. Reload your profile to see it."
        case .invalidCredentials: return "Check your handle or email and password, then try again."
        case .verifyEmail: return "Verify your email before continuing."
        case .unavailable: return "Account sign-in could not finish. Please try again."
        case .differentAccount: return "This sign-in method belongs to a different account."
        }
    }
}
