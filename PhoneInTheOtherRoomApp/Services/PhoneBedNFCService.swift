@preconcurrency import CoreNFC
import CryptoKit
import Foundation

@MainActor
final class PhoneBedNFCService: NSObject, ObservableObject {
    struct ReadResult: Equatable, Sendable {
        var digest: String
        var registrationID: UUID?
    }

    enum ScanResult {
        case read(ReadResult)
        case cancelled
        case unavailable(String)
    }

    enum ProvisionResult {
        case registered(PhoneBedTagRegistration)
        case alreadyPaired(String)
        case previouslyPaired(String)
        case cancelled
        case unavailable(String)
    }

    private enum Operation {
        case scan(isAdditionalQuiet: Bool, (ScanResult) -> Void)
        case provision(isAdditionalQuiet: Bool, PhoneBedTagProvisionIntent, UUID, Set<String>, Set<String>, (ProvisionResult) -> Void)
    }

    nonisolated private static let externalType = Data(
        "com.ngawangchime.countingsheep:phone-bed".utf8
    )

    private var session: NFCNDEFReaderSession?
    private var operation: Operation?

    func scan(
        isAdditionalQuiet: Bool = false,
        completion: @escaping (ScanResult) -> Void
    ) {
        let tagLabel = tagName(isAdditionalQuiet: isAdditionalQuiet)
        guard beginSession(
            operation: .scan(isAdditionalQuiet: isAdditionalQuiet, completion),
            message: "Hold the top of your iPhone near your \(tagLabel).",
            invalidateAfterFirstRead: false
        ) else {
            completion(.unavailable(unavailableMessage(isAdditionalQuiet: isAdditionalQuiet)))
            return
        }
    }

    func provision(
        isAdditionalQuiet: Bool = false,
        intent: PhoneBedTagProvisionIntent = .normalPairing,
        knownCredentialDigests: Set<String> = [],
        previouslyPairedCredentialDigests: Set<String> = [],
        completion: @escaping (ProvisionResult) -> Void
    ) {
        let registrationID = UUID()
        guard beginSession(
            operation: .provision(
                isAdditionalQuiet: isAdditionalQuiet,
                intent,
                registrationID,
                knownCredentialDigests,
                previouslyPairedCredentialDigests,
                completion
            ),
            message: "Hold the top of your iPhone near the NFC tag you want to pair.",
            invalidateAfterFirstRead: false
        ) else {
            completion(.unavailable(unavailableMessage(isAdditionalQuiet: isAdditionalQuiet)))
            return
        }
    }

    func cancel() {
        operation = nil
        session?.invalidate()
        session = nil
    }

    private func tagName(isAdditionalQuiet: Bool) -> String {
        isAdditionalQuiet ? "Phone Away tag" : "Wind Down tag"
    }

    private func unavailableMessage(isAdditionalQuiet _: Bool) -> String {
        "NFC is not available on this iPhone. Nothing changed."
    }

    private nonisolated static func readFailureMessage(isAdditionalQuiet _: Bool) -> String {
        "This tag could not be read. Try again. Nothing changed."
    }

    private nonisolated static func previouslyPairedMessage(isAdditionalQuiet: Bool) -> String {
        let purpose = isAdditionalQuiet ? "Phone Away" : "Wind Down"
        return "This tag was paired before but is no longer active for \(purpose). To use it again, resync it from Settings."
    }

    private nonisolated static func inspection(
        existingMessage: NFCNDEFMessage?,
        error: Error?
    ) -> PhoneBedTagInspection {
        let readError: PhoneBedTagReadError
        if let nfcError = error as? NFCReaderError,
           nfcError.code == .ndefReaderSessionErrorZeroLengthMessage {
            // Core NFC reports an empty, writable NDEF tag as a zero-length
            // message. That is the one documented error that is safe to treat
            // as a blank pairing surface.
            readError = .zeroLengthWritableTag
        } else {
            readError = error == nil ? .none : .unreadable
        }
        return PhoneBedTagReadResolutionPolicy.resolve(
            credentialDigest: existingMessage.map { readResult(from: $0).digest },
            error: readError
        )
    }

    private func beginSession(
        operation: Operation,
        message: String,
        invalidateAfterFirstRead: Bool
    ) -> Bool {
        guard NFCNDEFReaderSession.readingAvailable else { return false }
        session?.invalidate()
        self.operation = operation
        let session = NFCNDEFReaderSession(
            delegate: self,
            queue: nil,
            invalidateAfterFirstRead: invalidateAfterFirstRead
        )
        session.alertMessage = message
        self.session = session
        session.begin()
        return true
    }

    private nonisolated static func message(for registrationID: UUID) -> NFCNDEFMessage {
        NFCNDEFMessage(records: [
            NFCNDEFPayload(
                format: .nfcExternal,
                type: Self.externalType,
                identifier: Data(),
                payload: Data(registrationID.uuidString.lowercased().utf8)
            )
        ])
    }

    private nonisolated static func readResult(from message: NFCNDEFMessage) -> ReadResult {
        // A resync may only rewrite the exact one-record credential format we
        // own. Multi-record messages are occupied data, even if one record
        // happens to look familiar.
        if message.records.count == 1,
           let record = message.records.first,
           record.typeNameFormat == .nfcExternal,
           record.type == Self.externalType,
           let token = String(data: record.payload, encoding: .utf8),
           let registrationID = UUID(uuidString: token) {
            return ReadResult(
                digest: digest(Data(registrationID.uuidString.lowercased().utf8)),
                registrationID: registrationID
            )
        }
        return ReadResult(digest: fingerprint(message), registrationID: nil)
    }

    private nonisolated static func fingerprint(_ message: NFCNDEFMessage) -> String {
        var data = Data()
        for record in message.records {
            data.append(record.typeNameFormat.rawValue)
            data.append(record.type)
            data.append(record.identifier)
            data.append(record.payload)
        }
        return digest(data)
    }

    private nonisolated static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    @discardableResult
    private func finishScan(
        _ result: ScanResult,
        for readerSession: NFCNDEFReaderSession
    ) -> Bool {
        guard session === readerSession,
              case .scan(_, let completion) = operation else { return false }
        operation = nil
        session = nil
        completion(result)
        return true
    }

    @discardableResult
    private func finishProvision(
        _ result: ProvisionResult,
        for readerSession: NFCNDEFReaderSession
    ) -> Bool {
        guard session === readerSession,
              case .provision(_, _, _, _, _, let completion) = operation else { return false }
        operation = nil
        session = nil
        completion(result)
        return true
    }
}

extension PhoneBedNFCService: NFCNDEFReaderSessionDelegate {
    nonisolated func readerSession(
        _ session: NFCNDEFReaderSession,
        didInvalidateWithError error: Error
    ) {
        Task { @MainActor in
            guard self.session === session else { return }
            let cancelled = (error as? NFCReaderError)?.code
                == .readerSessionInvalidationErrorUserCanceled
            switch self.operation {
            case .scan(let isAdditionalQuiet, _):
                self.finishScan(
                    cancelled
                        ? .cancelled
                        : .unavailable(Self.readFailureMessage(isAdditionalQuiet: isAdditionalQuiet)),
                    for: session
                )
            case .provision:
                self.finishProvision(
                    cancelled
                        ? .cancelled
                        : .unavailable("This tag could not be prepared. Try again or use another writable NFC tag."),
                    for: session
                )
            case nil:
                break
            }
        }
    }

    nonisolated func readerSession(
        _ session: NFCNDEFReaderSession,
        didDetectNDEFs messages: [NFCNDEFMessage]
    ) {
        guard let message = messages.first else { return }
        let result = Self.readResult(from: message)
        Task { @MainActor in
            switch self.operation {
            case .scan:
                guard self.finishScan(.read(result), for: session) else { return }
                session.alertMessage = "Tag found."
                session.invalidate()
            case .provision(
                let isAdditionalQuiet,
                let intent,
                _,
                let knownCredentialDigests,
                let previouslyPairedCredentialDigests,
                _
            ):
                // Some NDEF tags arrive through didDetectNDEFs instead of the
                // tag callback. Inspect those records too so a stale Counting
                // Sheep credential never receives generic success feedback or
                // gets overwritten during replacement.
                switch PhoneBedTagProvisionPolicy.resolve(
                    intent: intent,
                    inspection: .credential(digest: result.digest),
                    activeCredentialDigests: knownCredentialDigests,
                    retiredCredentialDigests: previouslyPairedCredentialDigests
                ) {
                case .alreadyPaired:
                    let message = "That tag is already paired. Edit its name or uses instead."
                    guard self.finishProvision(.alreadyPaired(result.digest), for: session) else { return }
                    session.invalidate(errorMessage: message)
                case .previouslyPaired:
                    let message = Self.previouslyPairedMessage(isAdditionalQuiet: isAdditionalQuiet)
                    guard self.finishProvision(.previouslyPaired(result.digest), for: session) else { return }
                    session.invalidate(errorMessage: message)
                case .abort:
                    let message = "This tag already contains data. Hold a blank writable tag to pair it."
                    guard self.finishProvision(.unavailable(message), for: session) else { return }
                    session.invalidate(errorMessage: message)
                case .mayProceed where intent == .settingsRetiredTagResync:
                    // A retired credential is intentionally occupied. Wait for
                    // the tag callback, which supplies the writable NFCNDEFTag.
                    return
                case .mayProceed:
                    let message = "This tag already contains data. Hold a blank writable tag to pair it."
                    guard self.finishProvision(.unavailable(message), for: session) else { return }
                    session.invalidate(errorMessage: message)
                }
            case nil:
                break
            }
        }
    }

    nonisolated func readerSession(
        _ session: NFCNDEFReaderSession,
        didDetect tags: [NFCNDEFTag]
    ) {
        Task { @MainActor in
            guard self.session === session, let tag = tags.first else { return }
            let context = NFCWriteContext(session: session, tag: tag)
            if tags.count > 1 {
                context.session.alertMessage = "Hold only one tag near the top of your iPhone."
                context.session.restartPolling()
                return
            }

            switch self.operation {
            case .scan(let isAdditionalQuiet, _):
                self.read(context, isAdditionalQuiet: isAdditionalQuiet)
            case .provision(
                let isAdditionalQuiet,
                let intent,
                let registrationID,
                let knownCredentialDigests,
                let previouslyPairedCredentialDigests,
                _
            ):
                self.write(
                    context,
                    registrationID: registrationID,
                    intent: intent,
                    knownCredentialDigests: knownCredentialDigests,
                    previouslyPairedCredentialDigests: previouslyPairedCredentialDigests,
                    isAdditionalQuiet: isAdditionalQuiet
                )
            case nil:
                break
            }
        }
    }

    private func read(_ context: NFCWriteContext, isAdditionalQuiet: Bool) {
        context.session.connect(to: context.tag) { error in
            guard error == nil else {
                context.session.alertMessage = "The tag moved out of range. Hold it near the top of your iPhone and try again."
                context.session.restartPolling()
                return
            }
            context.tag.readNDEF { message, error in
                guard let message, error == nil else {
                    context.session.invalidate(
                        errorMessage: Self.readFailureMessage(isAdditionalQuiet: isAdditionalQuiet)
                    )
                    return
                }
                let result = Self.readResult(from: message)
                Task { @MainActor in
                    guard self.finishScan(.read(result), for: context.session) else { return }
                    let tagLabel = self.tagName(isAdditionalQuiet: isAdditionalQuiet).capitalized
                    context.session.alertMessage = "\(tagLabel) found."
                    context.session.invalidate()
                }
            }
        }
    }

    private func write(
        _ context: NFCWriteContext,
        registrationID: UUID,
        intent: PhoneBedTagProvisionIntent,
        knownCredentialDigests: Set<String>,
        previouslyPairedCredentialDigests: Set<String>,
        isAdditionalQuiet: Bool
    ) {
        context.session.connect(to: context.tag) { error in
            guard error == nil else {
                context.session.alertMessage = "The tag moved out of range. Hold it near the top of your iPhone and try again."
                context.session.restartPolling()
                return
            }
            context.tag.queryNDEFStatus { status, capacity, error in
                guard error == nil else {
                    context.session.invalidate(errorMessage: "This tag could not be checked. Nothing changed.")
                    return
                }
                context.tag.readNDEF { existingMessage, error in
                    let inspection = Self.inspection(
                        existingMessage: existingMessage,
                        error: error
                    )

                    switch PhoneBedTagProvisionPolicy.resolve(
                        intent: intent,
                        inspection: inspection,
                        activeCredentialDigests: knownCredentialDigests,
                        retiredCredentialDigests: previouslyPairedCredentialDigests
                    ) {
                    case .abort:
                        Task { @MainActor in
                            let message = "This tag could not be read safely. Try again. Nothing changed."
                            guard self.finishProvision(
                                .unavailable(message),
                                for: context.session
                            ) else { return }
                            context.session.invalidate(errorMessage: message)
                        }
                        return
                    case .alreadyPaired(let digest):
                        Task { @MainActor in
                            let message = "That tag is already paired. Edit its name or uses instead."
                            guard self.finishProvision(
                                .alreadyPaired(digest),
                                for: context.session
                            ) else { return }
                            context.session.invalidate(errorMessage: message)
                        }
                        return
                    case .previouslyPaired(let digest):
                        Task { @MainActor in
                            let message = Self.previouslyPairedMessage(isAdditionalQuiet: isAdditionalQuiet)
                            guard self.finishProvision(
                                .previouslyPaired(digest),
                                for: context.session
                            ) else { return }
                            context.session.invalidate(errorMessage: message)
                        }
                        return
                    case .mayProceed:
                        break
                    }
                    // `NFCNDEFMessage` is non-Sendable. Construct and hand it to
                    // Core NFC inside this callback rather than carrying it across
                    // the reader's callback boundary.
                    let message = Self.message(for: registrationID)
                    guard status == .readWrite,
                          capacity >= message.length else {
                        context.session.invalidate(
                            errorMessage: status == .readOnly
                                ? "That tag is read-only. Try a writable NFC tag."
                                : "That tag does not have enough room."
                        )
                        return
                    }
                    context.tag.writeNDEF(message) { error in
                        guard error == nil else {
                            context.session.invalidate(errorMessage: "This tag could not be written. Try again or use another writable NFC tag.")
                            return
                        }
                        guard PhoneBedTagSlotCommitPolicy.shouldCommit(.physicalWriteSucceeded) else {
                            return
                        }
                        let now = Date()
                        let registration = PhoneBedTagRegistration(
                            id: registrationID,
                            tokenDigest: Self.digest(
                                Data(registrationID.uuidString.lowercased().utf8)
                            ),
                            registeredAt: now,
                            lastVerifiedAt: now
                        )
                        Task { @MainActor in
                            guard self.finishProvision(
                                .registered(registration),
                                for: context.session
                            ) else { return }
                            context.session.alertMessage = isAdditionalQuiet
                                ? "Phone Away tag saved."
                                : "Wind Down tag saved."
                            context.session.invalidate()
                        }
                    }
                }
            }
        }
    }
}

private final class NFCWriteContext: @unchecked Sendable {
    let session: NFCNDEFReaderSession
    let tag: NFCNDEFTag

    init(session: NFCNDEFReaderSession, tag: NFCNDEFTag) {
        self.session = session
        self.tag = tag
    }
}
