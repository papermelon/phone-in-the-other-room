import CoreNFC
import CryptoKit
import Foundation

@MainActor
final class PhoneBedNFCService: NSObject, ObservableObject {
    enum Result { case read(String); case unavailable(String) }
    private var session: NFCNDEFReaderSession?
    private var completion: ((Result) -> Void)?

    func scan(completion: @escaping (Result) -> Void) {
        guard NFCNDEFReaderSession.readingAvailable else {
            completion(.unavailable("NFC is not available on this iPhone. You can use the QR phone bed instead."))
            return
        }
        self.completion = completion
        let session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
        session.alertMessage = "Hold the top of your iPhone near Ollie's phone-bed tag."
        self.session = session
        session.begin()
    }

    private func fingerprint(_ message: NFCNDEFMessage) -> String {
        var data = Data()
        for record in message.records {
            data.append(record.typeNameFormat.rawValue)
            data.append(record.type)
            data.append(record.identifier)
            data.append(record.payload)
        }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

extension PhoneBedNFCService: NFCNDEFReaderSessionDelegate {
    nonisolated func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        Task { @MainActor in
            guard let completion else { return }
            self.completion = nil
            if (error as? NFCReaderError)?.code != .readerSessionInvalidationErrorUserCanceled {
                completion(.unavailable("Ollie could not read that tag. Try again, or use the QR phone bed."))
            }
        }
    }

    nonisolated func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        Task { @MainActor in
            guard let message = messages.first, let completion else { return }
            self.completion = nil
            completion(.read(fingerprint(message)))
        }
    }
}
