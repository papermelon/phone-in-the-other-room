import SwiftUI

/// The one group agreement shown with an invite. Joining is the affirmative
/// action; the post-join state only reflects the canonical receipt retry.
struct SlumberPartySharedHabitsConsentDisclosure: View {
    let partyName: String
    let includesSharedNightPlans: Bool
    var actionLead: String? = nil
    var includesSharedHabits = true
    var includesChosenCharacter = true
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
                DisclosureGroup(isExpanded: $showsMore) {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("What members see").font(AppTypography.caption.weight(.semibold))
                        Text("Members see your Shepherd name, \(includesChosenCharacter ? "chosen character and its curated look" : "curated Shepherd look, Ollie ornament, featured sheep and pasture theme"), party role, round participation, brief app status and fixed cheers.")
                        Text("Wind Down and Phone Away entries are shared during seven-night rounds. Where supported, sharing starts when you join and continues between rounds. Group minutes are rounded.")
                        if includesSharedHabits {
                            Text(summaryDisclosure)
                            Text("Sleep duration comes only from eligible Apple Health records. Coverage shows how many nights are available. Missing data is unknown, never a missed habit.")
                        }
                        Text("Entries and statuses are recorded on each member’s iPhone and self-reported to Slumber Party. They are not independently verified and do not prove sleep or continuous phone placement.")
                        if includesSharedNightPlans {
                            Text("Your next seven local nights include a plan rounded to five minutes: Wind Down timing, bedtime and wake bookends, and ordered bundled routine ideas. Nightly results can include rounded start and end times, outcome, minutes, protection evidence and emergency-exit status. Routine ideas are plans, never proof of completion.")
                        }
                        Text("What stays private").font(AppTypography.caption.weight(.semibold))
                        Text("This agreement does not share your full Farm or wool, recurrence rule, exact schedule, custom purpose, routine or reflection text, selected apps or per-app use, Screen Time tokens or reports, raw Health samples, NFC or phone-bed credentials, or notification settings.")
                        if !includesSharedNightPlans {
                            Text("Routine ideas and planned times also stay private.")
                        }
                        Text("Leaving and removing records").font(AppTypography.caption.weight(.semibold))
                        Text("Leaving stops future sharing and removes your group access. Earlier shared records may remain visible. You can separately request their removal in Account and safety; removal is confirmed by the service. Your local Wind Down and Farm remain on this iPhone.")
                    }
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, AppSpacing.sm)
                } label: {
                    Label("Terms of agreement", systemImage: "checkmark.shield")
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.ink)
                        .frame(minHeight: 44)
                }
                .tint(AppColors.grass)
                .accessibilityIdentifier("slumberParty.terms")
                if onConfirm != nil {
                    Text(agreementTitle).font(AppTypography.caption)
                    if isSaving || isCheckingReceipt {
                        SheepLoadingView(isSaving ? "Saving your agreement…" : "Checking your agreement…")
                    }
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
        let action = actionLead ?? (onConfirm == nil ? "Continuing shares" : "Confirm to share")
        if includesSharedNightPlans {
            return "\(action) dated sleep-duration, Wind Down, and Phone Away summaries, plus your rounded next-seven-night Wind Down plan and app-recorded nightly results, with current and future members of \(partyName)."
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
