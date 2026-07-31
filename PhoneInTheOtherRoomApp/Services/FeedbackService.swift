import Foundation
import OSLog
import Supabase
import UIKit

enum FeedbackSubmissionError: LocalizedError {
    case backendDisabled
    case unavailable
    case dailyLimit
    case invalidResponse
    case imageUnreadable
    case imageCouldNotBeReduced

    var errorDescription: String? {
        switch self {
        case .backendDisabled:
            return "In-app delivery is resting in this build. You can still send this by email."
        case .unavailable:
            return "Feedback could not reach us just now. Your draft is still here."
        case .dailyLimit:
            return "You have sent several notes today. Please try again tomorrow or use email."
        case .invalidResponse:
            return "Feedback was sent, but its receipt could not be read."
        case .imageUnreadable:
            return "One screenshot could not be opened."
        case .imageCouldNotBeReduced:
            return "One screenshot could not be made small enough to send."
        }
    }
}

struct FeedbackImageProcessor {
    static let maximumPixelEdge: CGFloat = 2_048

    func prepare(data: Data, index: Int) throws -> FeedbackAttachment {
        guard let source = UIImage(data: data) else {
            throw FeedbackSubmissionError.imageUnreadable
        }
        let image = resizedImage(source)
        for quality in stride(
            from: CGFloat(0.82),
            through: CGFloat(0.30),
            by: CGFloat(-0.08)
        ) {
            guard let jpeg = image.jpegData(compressionQuality: quality) else { continue }
            if jpeg.count <= FeedbackAttachment.maximumBytes {
                return try FeedbackAttachment(
                    data: jpeg,
                    filename: "screenshot-\(index + 1).jpg"
                )
            }
        }
        throw FeedbackSubmissionError.imageCouldNotBeReduced
    }

    private func resizedImage(_ image: UIImage) -> UIImage {
        let longestEdge = max(image.size.width, image.size.height)
        guard longestEdge > Self.maximumPixelEdge else {
            return redraw(image, size: image.size)
        }
        let scale = Self.maximumPixelEdge / longestEdge
        let size = CGSize(
            width: max(1, floor(image.size.width * scale)),
            height: max(1, floor(image.size.height * scale))
        )
        return redraw(image, size: size)
    }

    private func redraw(_ image: UIImage, size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

actor SupabaseFeedbackService: FeedbackSubmitting {
    private struct SubmissionPayload: Encodable {
        let schemaVersion = 1
        let submissionID: UUID
        let category: FeedbackCategory
        let message: String
        let replyEmail: String?
        let diagnostics: FeedbackDiagnostics?
        let attachmentPaths: [String]
    }

    private struct SubmissionResponse: Decodable {
        let id: UUID
        let acceptedAt: String
    }

    private let provider: SupabaseClientProviding?
    private let authentication: SupabaseAuthenticating?
    private let feedbackEnabled: Bool
    private let logger = Logger(
        subsystem: "com.ngawangchime.countingsheep",
        category: "Feedback"
    )
    private let bucket = "feedback-attachments"

    init(bundle: Bundle = .main) {
        do {
            let configuration = try SupabaseConfiguration.load(bundle: bundle)
            let provider = ConfiguredSupabaseClientProvider(configuration: configuration)
            self.provider = provider
            authentication = SupabaseAuthenticationService(provider: provider)
            feedbackEnabled = configuration.feedbackEnabled
        } catch {
            provider = nil
            authentication = nil
            feedbackEnabled = false
        }
    }

    func submit(
        _ draft: ValidatedFeedbackDraft,
        attachments: [FeedbackAttachment],
        diagnostics: FeedbackDiagnostics?
    ) async throws -> FeedbackReceipt {
        guard feedbackEnabled else { throw FeedbackSubmissionError.backendDisabled }
        guard let provider, let authentication else {
            throw FeedbackSubmissionError.unavailable
        }
        let safeAttachments = try attachments.validatedForFeedback()
        let userID = try await authentication.authenticatedUserID()
        let client = try provider.client()
        let submissionID = UUID()
        let userPath = userID.uuidString.lowercased()
        let submissionPath = submissionID.uuidString.lowercased()
        var uploadedPaths: [String] = []
        var invokedSubmission = false

        do {
            for (index, attachment) in safeAttachments.enumerated() {
                let path = "\(userPath)/\(submissionPath)/attachment-\(index + 1).jpg"
                try await client.storage.from(bucket).upload(
                    path,
                    data: attachment.data,
                    options: FileOptions(
                        cacheControl: "0",
                        contentType: attachment.contentType,
                        upsert: false
                    )
                )
                uploadedPaths.append(path)
            }

            invokedSubmission = true
            let response: SubmissionResponse = try await client.functions.invoke(
                "submit-feedback",
                options: FunctionInvokeOptions(
                    headers: ["Idempotency-Key": submissionID.uuidString],
                    body: SubmissionPayload(
                        submissionID: submissionID,
                        category: draft.category,
                        message: draft.message,
                        replyEmail: draft.replyEmail,
                        diagnostics: draft.includeDiagnostics ? diagnostics : nil,
                        attachmentPaths: uploadedPaths
                    )
                )
            )
            guard let acceptedAt = FeedbackTimestamp.parse(response.acceptedAt) else {
                throw FeedbackSubmissionError.invalidResponse
            }
            return FeedbackReceipt(id: response.id, acceptedAt: acceptedAt)
        } catch {
            if !uploadedPaths.isEmpty,
               !invokedSubmission || error is FunctionsError {
                _ = try? await client.storage.from(bucket).remove(paths: uploadedPaths)
            }
#if DEBUG
            logger.notice(
                "Feedback submission failed. Error type=\(String(describing: type(of: error)), privacy: .public)"
            )
#endif
            if let submissionError = error as? FeedbackSubmissionError {
                throw submissionError
            }
            if let functionsError = error as? FunctionsError,
               case .httpError(let code, _) = functionsError,
               code == 429 {
                throw FeedbackSubmissionError.dailyLimit
            }
            throw FeedbackSubmissionError.unavailable
        }
    }
}
