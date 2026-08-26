import Foundation

enum FeedbackCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case bug
    case featureRequest
    case general

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bug: return "Bug"
        case .featureRequest: return "Feature idea"
        case .general: return "General"
        }
    }
}

struct FeedbackDraft: Equatable, Sendable {
    var category: FeedbackCategory
    var message: String
    var replyEmail: String
    var includeDiagnostics: Bool

    static let minimumMessageLength = 10
    static let maximumMessageLength = 4_000

    func validated() throws -> ValidatedFeedbackDraft {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedMessage.count >= Self.minimumMessageLength else {
            throw FeedbackValidationError.messageTooShort
        }
        guard trimmedMessage.count <= Self.maximumMessageLength else {
            throw FeedbackValidationError.messageTooLong
        }

        let trimmedEmail = replyEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedEmail.isEmpty, !Self.isValidEmail(trimmedEmail) {
            throw FeedbackValidationError.invalidEmail
        }

        return ValidatedFeedbackDraft(
            category: category,
            message: trimmedMessage,
            replyEmail: trimmedEmail.isEmpty ? nil : trimmedEmail,
            includeDiagnostics: includeDiagnostics
        )
    }

    private static func isValidEmail(_ value: String) -> Bool {
        guard value.count <= 254,
              !value.contains(where: { $0.isWhitespace }) else { return false }
        let parts = value.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2,
              !parts[0].isEmpty,
              parts[1].contains("."),
              !parts[1].hasPrefix("."),
              !parts[1].hasSuffix(".") else { return false }
        return true
    }
}

struct ValidatedFeedbackDraft: Equatable, Sendable {
    let category: FeedbackCategory
    let message: String
    let replyEmail: String?
    let includeDiagnostics: Bool
}

struct FeedbackDiagnostics: Codable, Equatable, Sendable {
    let appVersion: String
    let buildNumber: String
    let operatingSystem: String
    let deviceFamily: String
}

struct FeedbackAttachment: Equatable, Sendable {
    static let maximumCount = 3
    static let maximumBytes = 3_000_000

    let data: Data
    let filename: String
    let contentType: String

    init(data: Data, filename: String, contentType: String = "image/jpeg") throws {
        guard !data.isEmpty, data.count <= Self.maximumBytes else {
            throw FeedbackValidationError.attachmentTooLarge
        }
        guard contentType == "image/jpeg" else {
            throw FeedbackValidationError.unsupportedAttachment
        }
        self.data = data
        self.filename = filename
        self.contentType = contentType
    }
}

struct FeedbackReceipt: Codable, Equatable, Sendable {
    let id: UUID
    let acceptedAt: Date
}

enum FeedbackTimestamp {
    static func parse(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }
        return ISO8601DateFormatter().date(from: value)
    }
}

protocol FeedbackSubmitting: Sendable {
    func submit(
        _ draft: ValidatedFeedbackDraft,
        attachments: [FeedbackAttachment],
        diagnostics: FeedbackDiagnostics?
    ) async throws -> FeedbackReceipt
}

enum FeedbackValidationError: LocalizedError, Equatable {
    case messageTooShort
    case messageTooLong
    case invalidEmail
    case tooManyAttachments
    case attachmentTooLarge
    case unsupportedAttachment

    var errorDescription: String? {
        switch self {
        case .messageTooShort:
            return "Please share at least 10 characters so we can understand what happened."
        case .messageTooLong:
            return "Please keep feedback under 4,000 characters."
        case .invalidEmail:
            return "That reply email does not look complete. You can also leave it blank."
        case .tooManyAttachments:
            return "You can add up to three screenshots."
        case .attachmentTooLarge:
            return "One screenshot is still too large to send."
        case .unsupportedAttachment:
            return "That attachment could not be prepared as a screenshot."
        }
    }
}

extension Array where Element == FeedbackAttachment {
    func validatedForFeedback() throws -> [FeedbackAttachment] {
        guard count <= FeedbackAttachment.maximumCount else {
            throw FeedbackValidationError.tooManyAttachments
        }
        return self
    }
}
