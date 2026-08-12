import MessageUI
import PhotosUI
import SwiftUI
import UIKit

struct FeedbackFormView: View {
    private enum SubmissionPhase: Equatable {
        case idle
        case preparing
        case uploading
        case submitted(FeedbackReceipt)
    }

    private let submitter: any FeedbackSubmitting

    @State private var category: FeedbackCategory = .bug
    @State private var message = ""
    @State private var replyEmail = ""
    @State private var includeDiagnostics = true
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var attachments: [FeedbackAttachment] = []
    @State private var phase: SubmissionPhase = .idle
    @State private var errorMessage: String?
    @State private var showMailComposer = false
    @State private var showMailUnavailable = false

    init(submitter: any FeedbackSubmitting = SupabaseFeedbackService()) {
        self.submitter = submitter
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                introduction
                if case .submitted(let receipt) = phase {
                    submittedCard(receipt)
                } else {
                    categoryCard
                    messageCard
                    screenshotsCard
                    diagnosticsCard
                    privacyCard
                    submissionControls
                }
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Send Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedItems) { _, items in
            prepareAttachments(from: items)
        }
        .sheet(isPresented: $showMailComposer) {
            FeedbackMailComposer(draft: mailDraft)
        }
        .alert("Email is not set up", isPresented: $showMailUnavailable) {
            Button("Copy again") {
                UIPasteboard.general.string = Self.supportEmail
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("\(Self.supportEmail) was copied. You can send your note from any email app.")
        }
    }

    private var introduction: some View {
        PixelCard {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                OllieRitualView(state: .ready, presentation: .inline)
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Tell us what you noticed")
                        .font(AppTypography.headline)
                    Text("A bug, an idea, or something that felt unclear. Every note helps us make Wind Down gentler.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.muted)
                }
            }
        }
    }

    private var categoryCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("What kind of note is this?")
                    .font(AppTypography.headline)
                Picker("Feedback category", selection: $category) {
                    ForEach(FeedbackCategory.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var messageCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("What happened?")
                    .font(AppTypography.headline)
                TextEditor(text: $message)
                    .font(AppTypography.body)
                    .frame(minHeight: 150)
                    .padding(AppSpacing.xs)
                    .background(
                        AppColors.background,
                        in: RoundedRectangle(cornerRadius: AppRadius.md)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .stroke(AppColors.stroke.opacity(0.22), lineWidth: 1)
                    }
                    .accessibilityLabel("Feedback message")
                Text("\(message.count) / \(FeedbackDraft.maximumMessageLength)")
                    .font(AppTypography.caption)
                    .foregroundStyle(
                        message.count > FeedbackDraft.maximumMessageLength
                            ? AppColors.amber
                            : AppColors.muted
                    )
                    .frame(maxWidth: .infinity, alignment: .trailing)

                TextField("Reply email (optional)", text: $replyEmail)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                Text("Add an email only if you would like a reply.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
        }
    }

    private var screenshotsCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Screenshots")
                    .font(AppTypography.headline)
                Text("Optional. Add up to three images. Counting Sheep removes photo metadata and makes each image smaller before sending.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: FeedbackAttachment.maximumCount,
                    matching: .images
                ) {
                    Label(
                        attachments.isEmpty ? "Add screenshots" : "Change screenshots",
                        systemImage: "photo.on.rectangle.angled"
                    )
                }
                .buttonStyle(PixelChipButtonStyle(isSelected: false))
                if !attachments.isEmpty {
                    Label(
                        "\(attachments.count) screenshot\(attachments.count == 1 ? "" : "s") ready",
                        systemImage: "checkmark.circle.fill"
                    )
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.grass)
                }
            }
        }
    }

    private var diagnosticsCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Toggle("Include technical details", isOn: $includeDiagnostics)
                    .font(AppTypography.headline)
                Text("App \(diagnostics.appVersion) (\(diagnostics.buildNumber)) · \(diagnostics.operatingSystem) · \(diagnostics.deviceFamily)")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                Text("No logs, sleep data, selected apps, schedule, NFC details, or device identifier are included.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
        }
    }

    private var privacyCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Label("Your note leaves this iPhone only when you tap Send.", systemImage: "hand.raised.fill")
                    .font(AppTypography.body)
                Text("Please leave out sensitive health or personal information you do not want the Counting Sheep team to receive.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
        }
    }

    private var submissionControls: some View {
        VStack(spacing: AppSpacing.sm) {
            if let errorMessage {
                PixelCard {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Your draft is still here.")
                            .font(AppTypography.headline)
                        Text(errorMessage)
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.muted)
                        Button("Send by email", action: sendByEmail)
                            .buttonStyle(PixelChipButtonStyle(isSelected: false))
                    }
                }
            }
            Button(action: submit) {
                HStack {
                    if phase == .preparing || phase == .uploading {
                        ProgressView().tint(AppColors.paper)
                    }
                    Text(submitTitle)
                    Spacer()
                    Image(systemName: "paperplane.fill")
                }
                .font(AppTypography.headline)
            }
            .buttonStyle(PixelPrimaryButtonStyle())
            .disabled(phase == .preparing || phase == .uploading)
        }
    }

    private func submittedCard(_ receipt: FeedbackReceipt) -> some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Label("Your note reached the pasture", systemImage: "checkmark.circle.fill")
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.grass)
                Text("Thank you. We will read it with care.")
                    .font(AppTypography.body)
                Text("Reference \(receipt.id.uuidString.prefix(8))")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
        }
    }

    private var submitTitle: String {
        switch phase {
        case .preparing: return "Preparing screenshots…"
        case .uploading: return "Sending…"
        case .idle, .submitted: return "Send feedback"
        }
    }

    private var diagnostics: FeedbackDiagnostics {
        FeedbackDiagnostics(
            appVersion: Bundle.main.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String ?? "unknown",
            buildNumber: Bundle.main.object(
                forInfoDictionaryKey: "CFBundleVersion"
            ) as? String ?? "unknown",
            operatingSystem: "iOS \(UIDevice.current.systemVersion)",
            deviceFamily: UIDevice.current.userInterfaceIdiom == .phone ? "iPhone" : "Apple device"
        )
    }

    private var currentDraft: FeedbackDraft {
        FeedbackDraft(
            category: category,
            message: message,
            replyEmail: replyEmail,
            includeDiagnostics: includeDiagnostics
        )
    }

    private var mailDraft: FeedbackMailDraft {
        let validated = try? currentDraft.validated()
        let detailLines = includeDiagnostics
            ? "\n\nTechnical details\nApp \(diagnostics.appVersion) (\(diagnostics.buildNumber))\n\(diagnostics.operatingSystem)\n\(diagnostics.deviceFamily)"
            : ""
        let replyLine = validated?.replyEmail.map { "\nReply email: \($0)" } ?? ""
        return FeedbackMailDraft(
            subject: "Counting Sheep \(category.title)",
            body: "\(message)\(replyLine)\(detailLines)",
            attachments: attachments
        )
    }

    private func prepareAttachments(from items: [PhotosPickerItem]) {
        guard !items.isEmpty else {
            attachments = []
            return
        }
        phase = .preparing
        errorMessage = nil
        Task { @MainActor in
            do {
                var prepared: [FeedbackAttachment] = []
                for (index, item) in items.enumerated() {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        throw FeedbackSubmissionError.imageUnreadable
                    }
                    let attachment = try await Task.detached(priority: .userInitiated) {
                        try FeedbackImageProcessor().prepare(data: data, index: index)
                    }.value
                    prepared.append(attachment)
                }
                attachments = try prepared.validatedForFeedback()
                phase = .idle
            } catch {
                attachments = []
                selectedItems = []
                errorMessage = error.localizedDescription
                phase = .idle
            }
        }
    }

    private func submit() {
        errorMessage = nil
        do {
            let validated = try currentDraft.validated()
            let safeAttachments = try attachments.validatedForFeedback()
            phase = .uploading
            Task { @MainActor in
                do {
                    let receipt = try await submitter.submit(
                        validated,
                        attachments: safeAttachments,
                        diagnostics: includeDiagnostics ? diagnostics : nil
                    )
                    phase = .submitted(receipt)
                } catch {
                    if let submissionError = error as? FeedbackSubmissionError,
                       case .backendDisabled = submissionError {
                        phase = .idle
                        sendByEmail()
                        return
                    }
                    errorMessage = error.localizedDescription
                    phase = .idle
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func sendByEmail() {
        guard MFMailComposeViewController.canSendMail() else {
            UIPasteboard.general.string = Self.supportEmail
            showMailUnavailable = true
            return
        }
        showMailComposer = true
    }

    private static let supportEmail = "countingsheep.sg@gmail.com"
}

struct FeedbackMailDraft {
    let subject: String
    let body: String
    let attachments: [FeedbackAttachment]
}

private struct FeedbackMailComposer: UIViewControllerRepresentable {
    let draft: FeedbackMailDraft

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients(["countingsheep.sg@gmail.com"])
        controller.setSubject(draft.subject)
        controller.setMessageBody(draft.body, isHTML: false)
        for attachment in draft.attachments {
            controller.addAttachmentData(
                attachment.data,
                mimeType: attachment.contentType,
                fileName: attachment.filename
            )
        }
        return controller
    }

    func updateUIViewController(
        _ uiViewController: MFMailComposeViewController,
        context: Context
    ) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            controller.dismiss(animated: true)
        }
    }
}

#Preview("Feedback form") {
    NavigationStack {
        FeedbackFormView()
    }
}
