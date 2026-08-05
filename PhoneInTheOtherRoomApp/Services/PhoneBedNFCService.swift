@preconcurrency import CoreNFC
import CryptoKit
import Foundation

@MainActor
final class PhoneBedNFCService: NSObject, ObservableObject {
    struct ReadResult: Equatable {
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
        case cancelled
        case unavailable(String)
    }

    private enum Operation {
        case scan((ScanResult) -> Void)
        case provision(UUID, (ProvisionResult) -> Void)
    }

    nonisolated private static let externalType = Data(
        "com.ngawangchime.countingsheep:phone-bed".utf8
    )

    private var session: NFCNDEFReaderSession?
    private var operation: Operation?

    func scan(completion: @escaping (ScanResult) -> Void) {
        guard beginSession(
            operation: .scan(completion),
            message: "Hold the top of your iPhone near your Wind Down tag.",
            invalidateAfterFirstRead: false
        ) else {
            completion(.unavailable(unavailableMessage))
            return
        }
    }

    func provision(completion: @escaping (ProvisionResult) -> Void) {
        let registrationID = UUID()
        guard beginSession(
            operation: .provision(registrationID, completion),
            message: "Hold the top of your iPhone near the tag you want Ollie to remember.",
            invalidateAfterFirstRead: false
        ) else {
            completion(.unavailable(unavailableMessage))
            return
        }
    }

    private var unavailableMessage: String {
        "NFC is not available on this iPhone. You can use a Wind Down code instead."
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
        if let record = message.records.first(where: {
            $0.typeNameFormat == .nfcExternal && $0.type == Self.externalType
        }),
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

    private func finishScan(_ result: ScanResult) {
        guard case .scan(let completion) = operation else { return }
        operation = nil
        session = nil
        completion(result)
    }

    private func finishProvision(_ result: ProvisionResult) {
        guard case .provision(_, let completion) = operation else { return }
        operation = nil
        session = nil
        completion(result)
    }
}

extension PhoneBedNFCService: NFCNDEFReaderSessionDelegate {
    nonisolated func readerSession(
        _ session: NFCNDEFReaderSession,
        didInvalidateWithError error: Error
    ) {
        Task { @MainActor in
            let cancelled = (error as? NFCReaderError)?.code
                == .readerSessionInvalidationErrorUserCanceled
            switch self.operation {
            case .scan:
                self.finishScan(
                    cancelled
                        ? .cancelled
                        : .unavailable("Ollie could not read that tag. Try again, pair a replacement tag, or use a Wind Down code.")
                )
            case .provision:
                self.finishProvision(
                    cancelled
                        ? .cancelled
                        : .unavailable("Ollie could not prepare that tag. Try another tag, or use a Wind Down code.")
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
        Task { @MainActor in
            guard case .scan = self.operation,
                  let message = messages.first else { return }
            self.finishScan(.read(Self.readResult(from: message)))
            session.alertMessage = "Wind Down tag found."
            session.invalidate()
        }
    }

    nonisolated func readerSession(
        _ session: NFCNDEFReaderSession,
        didDetect tags: [NFCNDEFTag]
    ) {
        Task { @MainActor in
            guard let tag = tags.first else { return }
            let context = NFCWriteContext(session: session, tag: tag)
            if tags.count > 1 {
                context.session.alertMessage = "Hold only one tag near the top of your iPhone."
                context.session.restartPolling()
                return
            }

            switch self.operation {
            case .scan:
                self.read(context)
            case .provision(let registrationID, _):
                self.write(context, registrationID: registrationID)
            case nil:
                break
            }
        }
    }

    private func read(_ context: NFCWriteContext) {
        context.session.connect(to: context.tag) { error in
            guard error == nil else {
                context.session.alertMessage = "Ollie could not reach that tag. Try again."
                context.session.restartPolling()
                return
            }
            context.tag.readNDEF { message, error in
                guard let message, error == nil else {
                    context.session.invalidate(
                        errorMessage: "Ollie could not read that tag. Try again, pair a replacement tag, or use a Wind Down code."
                    )
                    return
                }
                let result = Self.readResult(from: message)
                Task { @MainActor in
                    self.finishScan(.read(result))
                    context.session.alertMessage = "Wind Down tag found."
                    context.session.invalidate()
                }
            }
        }
    }

    private func write(
        _ context: NFCWriteContext,
        registrationID: UUID
    ) {
        context.session.connect(to: context.tag) { error in
            guard error == nil else {
                context.session.alertMessage = "Ollie could not reach that tag. Try again."
                context.session.restartPolling()
                return
            }
            context.tag.queryNDEFStatus { status, capacity, error in
                guard error == nil else {
                    context.session.invalidate(errorMessage: "Ollie could not check that tag.")
                    return
                }
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
                        context.session.invalidate(errorMessage: "Ollie could not write to that tag.")
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
                        self.finishProvision(.registered(registration))
                        context.session.alertMessage = "Wind Down tag saved."
                        context.session.invalidate()
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
