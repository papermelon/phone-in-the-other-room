import SwiftUI

struct SharedTextSafetyPromptModifier: ViewModifier {
    @ObservedObject var social: NightFlockViewModel
    private var isConsent: Bool { social.sharedTextSafetyPrompt?.code == .sharedTextConsentRequired }
    private var isReview: Bool { social.sharedTextSafetyPrompt?.code == .sharedTextReviewRequired }

    func body(content: Content) -> some View {
        content.alert(isConsent ? "Shared-text safety" : isReview ? "Review your shared text" : "Edit your shared text", isPresented: Binding(
            get: { social.sharedTextSafetyPrompt?.ownerID == social.pastureOwner && social.sharedTextSafetyPrompt != nil },
            set: { if !$0 { social.dismissSharedTextSafetyPrompt() } }
        )) {
            if isConsent || isReview {
                Button(isConsent ? "Allow safety checks" : "Share this text") { social.confirmSharedTextSafetyPrompt() }
            }
            Button(isConsent ? "Not now" : "Edit first", role: .cancel) { social.dismissSharedTextSafetyPrompt() }
        } message: {
            Text(isConsent
                ? "Shared names, notes, intentions and profile text are sent to OpenAI to check for hate, threats and harassment. This includes new and pending shared text. Private Nights reflections stay on your device. Your sharing audience stays the same."
                : isReview ? "This change may contain hurtful language. Review what you’re sharing. If the context is appropriate, you can confirm sharing this text."
                : social.sharedTextSafetyPrompt?.message ?? "Your text wasn’t shared. Edit it before trying again.")
        }
    }
}

extension View {
    func sharedTextSafetyPrompt(social: NightFlockViewModel) -> some View {
        modifier(SharedTextSafetyPromptModifier(social: social))
    }
}

struct SharedTextSafetySettings: View {
    @ObservedObject var social: NightFlockViewModel
    let ownerID: UUID
    @AppStorage private var consentVersion: Int
    init(social: NightFlockViewModel, ownerID: UUID) {
        self.social = social; self.ownerID = ownerID
        _consentVersion = AppStorage(wrappedValue: 0, SharedTextSafety.consentKey(ownerID: ownerID), store: social.defaults)
    }
    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Shared-text safety").font(AppTypography.headline)
                Text("With your permission, shared text can be checked by OpenAI for hate, threats and harassment. Private Nights reflections stay local.")
                    .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                Text(consentVersion == SharedTextSafety.version ? "Safety checks allowed on this iPhone" : "Permission will be requested before a safety check")
                    .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                if consentVersion == SharedTextSafety.version {
                    Button("Stop allowing safety checks") { social.revokeSharedTextConsent(ownerID: ownerID) }
                        .buttonStyle(PixelChipButtonStyle(isSelected: false))
                        .accessibilityHint("Future shared text will wait for your permission. Checks already sent can finish.")
                }
            }
        }
    }
}

#Preview("Shared text · consent") {
    SharedTextSafetyPreview(code: .sharedTextConsentRequired)
}

#Preview("Shared text · review") { SharedTextSafetyPreview(code: .sharedTextReviewRequired) }

#Preview("Shared text · reword") { SharedTextSafetyPreview(code: .sharedTextRejected) }

#if DEBUG
private struct SharedTextSafetyPreview: View {
    @StateObject private var social: NightFlockViewModel
    init(code: NightFlockRemoteErrorCode) {
        let defaults = UserDefaults(suiteName: "SharedTextSafetyPreview.\(UUID())")!
        let owner = UUID()
        defaults.set(owner.uuidString, forKey: NightFlockAccountService.expectedLinkedUserIDKey)
        let model = NightFlockViewModel(featureEnabled: true, previewPhase: .ready, previewAccountState: .linked, defaults: defaults)
        model.sharedTextSafetyPrompt = .init(ownerID: owner, code: code, reviewToken: String(repeating: "a", count: 64))
        _social = StateObject(wrappedValue: model)
    }
    var body: some View {
        Text("Your shared text is waiting.").font(AppTypography.body)
            .frame(maxWidth: .infinity, maxHeight: .infinity).background(AppColors.paper)
            .sharedTextSafetyPrompt(social: social)
    }
}
#endif
