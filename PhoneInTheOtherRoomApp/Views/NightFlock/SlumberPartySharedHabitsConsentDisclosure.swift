import SwiftUI

/// The one group agreement shown with an invite. Joining is the affirmative
/// action; the post-join state only reflects the canonical receipt retry.
struct SlumberPartySharedHabitsConsentDisclosure: View {
    let partyName: String
    let includesSharedNightPlans: Bool
    var receiptIsPending = false
    var isSaving = false
    var isCheckingReceipt = false
    var requiresExistingMemberAffirmation = false
    var errorDetail: String?
    var onConfirm: (() -> Void)?
    @State private var showsMore = false

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Label("SHARED HABITS AGREEMENT", systemImage: "person.2.badge.gearshape")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                Text(agreementTitle)
                    .font(AppTypography.headline)
                Text(summaryDisclosure)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Accepted history stays for this party’s lifetime, including after you leave. You can request deletion of your shared records.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    showsMore.toggle()
                } label: {
                    HStack(spacing: AppSpacing.xs) {
                        Text(showsMore ? "See less" : "See more")
                        Image(systemName: showsMore ? "chevron.up" : "chevron.down")
                    }
                    .font(AppTypography.caption.weight(.semibold))
                }
                .frame(minHeight: 44)
                .foregroundStyle(AppColors.grass)
                .accessibilityValue(showsMore ? "Expanded" : "Collapsed")
                .accessibilityIdentifier("slumberParty.sharedHabitsAgreement.seeMore")
                .accessibilityHint("Shows what stays private and what happens when you leave.")
                if showsMore {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("Coverage shows the available nights behind a summary. Missing data is unavailable, not a missed habit.")
                        if includesSharedNightPlans {
                            Text("The group also receives a plan rounded to five minutes for your next seven local nights: Wind Down timing, bedtime and wake bookends for comparison, and ordered bundled routine ideas.")
                            Text("Factual nightly results can include rounded start and terminal timing, outcome and minutes, protection evidence, and emergency-exit status. Missing evidence stays unknown. Ideas are planned context, never verified completion.")
                            Text("Your recurrence rule, custom routine text, exact app identity, per-app use, raw Health samples, Screen Time tokens, and phone-bed credentials stay private.")
                        } else {
                            Text("Your recurrence rule, routine ideas and custom text, exact times, raw Health samples, app identity, per-app use, Screen Time tokens, and phone-bed credentials stay private.")
                        }
                        Text("Leaving stops future sharing and group access. Earlier accepted records remain in the archive unless a deletion request is completed.")
                    }
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                }
                if let errorDetail {
                    Text(errorDetail)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let onConfirm {
                    Button(confirmButtonTitle) {
                        onConfirm()
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .buttonStyle(PixelPrimaryButtonStyle())
                    .disabled(isSaving || isCheckingReceipt)
                }
            }
        }
    }

    private var agreementTitle: String {
        if isSaving {
            return "Saving your agreement…"
        }
        if isCheckingReceipt {
            return "Checking agreement…"
        }
        if receiptIsPending || errorDetail != nil {
            return "Agreement not confirmed"
        }
        return affirmationTitle
    }

    private var summaryDisclosure: String {
        let action = onConfirm == nil ? "Joining includes sharing" : "Confirm to share"
        if includesSharedNightPlans {
            return "\(action) dated sleep-duration, Wind Down, and Phone Away summaries, plus your rounded next-seven-night Wind Down plan and factual nightly results, with current and future members of \(partyName)."
        }
        return "\(action) dated sleep-duration, Wind Down, and Phone Away summaries with current and future members of \(partyName)."
    }

    private var affirmationTitle: String {
        requiresExistingMemberAffirmation
            ? "Confirm the expanded group agreement"
            : "One agreement for this Slumber Party"
    }

    private var confirmButtonTitle: String {
        if isSaving {
            return "Saving agreement…"
        }
        if isCheckingReceipt {
            return "Checking agreement…"
        }
        if receiptIsPending || errorDetail != nil {
            return "Retry agreement"
        }
        return requiresExistingMemberAffirmation ? "Confirm agreement" : "Agree and continue"
    }
}

#Preview("Shared habits agreement") {
    SlumberPartySharedHabitsConsentDisclosure(
        partyName: "Night Owls",
        includesSharedNightPlans: false,
        onConfirm: {}
    )
        .padding()
        .background(AppColors.paper)
}

#Preview("Shared habits v2 agreement") {
    SlumberPartySharedHabitsConsentDisclosure(
        partyName: "Night Owls",
        includesSharedNightPlans: true,
        receiptIsPending: true,
        errorDetail: "We couldn’t confirm your agreement. Please try again.",
        onConfirm: {}
    )
    .padding()
    .background(AppColors.paper)
}

#Preview("Shared habits agreement saving") {
    SlumberPartySharedHabitsConsentDisclosure(
        partyName: "Night Owls",
        includesSharedNightPlans: true,
        isSaving: true,
        onConfirm: {}
    )
    .padding()
    .background(AppColors.paper)
}
