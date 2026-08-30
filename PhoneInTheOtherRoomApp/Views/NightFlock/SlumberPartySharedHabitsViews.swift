import SwiftUI

/// A focused section for the server-backed, receipt-gated habit archive. The
/// parent detail view owns placement and fetch timing; this view owns only its
/// consent, summary, and archive presentation.
struct SlumberPartySharedHabitsSection: View {
    @ObservedObject var viewModel: NightFlockViewModel
    let partyID: UUID
    let partyName: String
    var members: [NightFlockV4Membership] = []
    var myMemberID: UUID?
    var healthActionTitle: String?
    var onHealthAction: (() -> Void)?

    private var state: NightFlockSharedHabitsStateResponse? {
        viewModel.sharedHabitsState(for: partyID)
    }

    private var isLoading: Bool {
        viewModel.sharedHabitsLoadingPartyIDs.contains(partyID)
    }

    private var loadingOrRetryErrorDetail: String? {
        if case let .error(message) = viewModel.phase { return message }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            if !viewModel.supportsSharedHabits {
                unsupportedCard
            } else if let state {
                if state.agreement == nil {
                    agreementStateCard
                } else {
                    if viewModel.requiresSharedNightPlanAgreement(partyID: partyID) {
                        v2ReconsentCard
                    }
                    sharedArchive(state)
                }
            } else {
                loadingOrRetryCard
            }
        }
        .onAppear {
            guard viewModel.supportsSharedHabits, state == nil else { return }
            viewModel.refreshSharedHabits(partyID: partyID)
        }
    }

    private var agreementStateCard: some View {
        let receiptPending = viewModel.isSharedHabitsJoinAgreementReceiptPending(partyID: partyID)
        return SlumberPartySharedHabitsConsentDisclosure(
            partyName: partyName,
            includesSharedNightPlans: viewModel.supportsSharedNightPlans,
            receiptIsPending: receiptPending,
            isSaving: viewModel.sharedHabitsAgreementSavingPartyIDs.contains(partyID),
            isCheckingReceipt: isLoading,
            requiresExistingMemberAffirmation: !receiptPending,
            errorDetail: viewModel.sharedHabitsAgreementErrors[partyID],
            onConfirm: { viewModel.acceptSharedHabitsAgreement(partyID: partyID) }
        )
    }

    private var v2ReconsentCard: some View {
        SlumberPartySharedHabitsConsentDisclosure(
            partyName: partyName,
            includesSharedNightPlans: true,
            isSaving: viewModel.sharedHabitsAgreementSavingPartyIDs.contains(partyID),
            isCheckingReceipt: isLoading,
            requiresExistingMemberAffirmation: true,
            errorDetail: viewModel.sharedHabitsAgreementErrors[partyID],
            onConfirm: { viewModel.acceptSharedHabitsAgreement(partyID: partyID) }
        )
    }

    private var unsupportedCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Label("SHARED HABITS", systemImage: "clock.badge.questionmark")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                Text("This group service is not ready for shared habit summaries.")
                    .font(AppTypography.body.weight(.semibold))
                Text("Your local Wind Down and sleep context stay on this iPhone.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
            }
        }
    }

    private var loadingOrRetryCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Label("SHARED HABITS", systemImage: "clock")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                Text(isLoading ? "Opening shared summaries…" : "Shared summaries need a refresh.")
                    .font(AppTypography.body.weight(.semibold))
                if let loadingOrRetryErrorDetail {
                    Text(loadingOrRetryErrorDetail)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Nothing is shared until this group has confirmed your agreement.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                }
                if !isLoading {
                    Button("Refresh summaries") { viewModel.refreshSharedHabits(partyID: partyID) }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .buttonStyle(PixelChipButtonStyle(isSelected: false))
                }
            }
        }
    }

    private var shouldOfferHealthAction: Bool {
        guard let state, let myMemberID else { return false }
        return !state.periods.contains {
            $0.memberID == myMemberID
                && $0.kind == .sleep
                && $0.coveredNights > 0
        }
    }

    private func healthConnectionCard(title: String, action: @escaping () -> Void) -> some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("YOUR SLEEP SUMMARY")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                Text("No observed sleep summary yet")
                    .font(AppTypography.headline)
                Text("Apple Health is optional. Connecting or refreshing can add a consented sleep-duration summary when Health has one; it never shares raw samples.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Button(title, action: action)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .buttonStyle(PixelChipButtonStyle(isSelected: false))
            }
        }
    }

    private func sharedArchive(_ state: NightFlockSharedHabitsStateResponse) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("SHARED HABITS")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                Text("Quiet summaries, with coverage")
                    .font(AppTypography.title)
                Text("Means use only nights with an observed eligible value. Coverage shows how many nights are included.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if shouldOfferHealthAction, let healthActionTitle, let onHealthAction {
                healthConnectionCard(title: healthActionTitle, action: onHealthAction)
            }
            Text("Exact app-use sharing is unavailable for Singapore groups.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            DisclosureGroup("Archive and source details") {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Sleep duration is a consented Health summary when available. Wind Down and Phone Away are factual local app records.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    if state.agreement?.agreementVersion ?? 1 >= 2 {
                        Text("The v2 archive can include bounded, rounded next-seven-night plan instances and factual nightly receipts. Your recurrence rule, custom routine text, exact app identity, per-app use, raw samples, Screen Time tokens, and phone-bed credentials are never shared.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("Exact selected apps, recurrence rules, routines, raw samples, schedules, and stages are never shared.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    SlumberPartySharedHabitsArchive(records: state.records)
                }
                .padding(.top, AppSpacing.sm)
            }
            .font(AppTypography.caption.weight(.semibold))
            if let nextCursor = state.nextCursor {
                Button(isLoading ? "Loading earlier summaries…" : "Load earlier summaries") {
                    _ = nextCursor
                    viewModel.loadMoreSharedHabits(partyID: partyID)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .buttonStyle(PixelChipButtonStyle(isSelected: false))
                .disabled(isLoading)
            }
            Button(isLoading ? "Refreshing…" : "Refresh summaries") {
                viewModel.refreshSharedHabits(partyID: partyID)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .buttonStyle(PixelChipButtonStyle(isSelected: false))
            .disabled(isLoading)
        }
    }
}

/// The v2 social loop is intentionally a compact factual layer above the
/// archive. It does not introduce a feed, rank, or another active-run route.
struct SlumberPartySharedNightLoopSection: View {
    let party: NightFlockV4PartyDetail
    let state: NightFlockSharedHabitsStateResponse
    let now: Date
    @ObservedObject var appViewModel: FocusRunViewModel
    @State private var borrowNotice: String?

    private var activePlans: [SharedNightPlan] {
        state.sharedNightPlans.filter { $0.supersededAt == nil && !$0.isFormerMember }
    }

    private var tonightPlans: [SharedNightPlan] {
        let eligible = activePlans.filter { plan in
            guard plan.morningQuietEnd >= now else { return false }
            guard let today = NightFlockLocalDate(date: now, timeZoneIdentifier: plan.timeZoneIdentifier) else { return false }
            guard let tomorrow = date(after: today, in: plan.timeZoneIdentifier) else { return plan.nightEndingDate == today }
            return plan.nightEndingDate == today || plan.nightEndingDate == tomorrow
        }
        return Dictionary(grouping: eligible, by: \.memberID).values.compactMap {
            $0.min { lhs, rhs in
                if lhs.nightEndingDate != rhs.nightEndingDate { return lhs.nightEndingDate < rhs.nightEndingDate }
                return lhs.revision > rhs.revision
            }
        }.sorted { $0.plannedWindDownStart < $1.plannedWindDownStart }
    }

    private var mosaicPlans: [SharedNightPlan] {
        SharedNightMosaicPresentation.plans(
            in: mosaicDates,
            plans: state.sharedNightPlans,
            receipts: mosaicReceipts
        )
    }

    private var mosaicReceipts: [SharedNightReceipt] {
        SharedNightMosaicPresentation.receipts(in: mosaicDates, from: state.sharedNightReceipts)
    }

    private var mosaicDates: Set<NightFlockLocalDate> {
        guard let round = party.summary.currentRound else {
            return Set(tonightPlans.map(\.nightEndingDate))
        }
        guard let start = round.startsOn.date(in: round.timeZoneIdentifier) else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: round.timeZoneIdentifier) ?? .current
        return Set((0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: start).flatMap {
                NightFlockLocalDate(date: $0, timeZoneIdentifier: round.timeZoneIdentifier, calendar: calendar)
            }
        })
    }

    private var orderedRecentReceipts: [SharedNightReceipt] {
        state.sharedNightReceipts.sorted { lhs, rhs in
            let lhsDate = lhs.terminalAt ?? lhs.actualStart ?? .distantPast
            let rhsDate = rhs.terminalAt ?? rhs.actualStart ?? .distantPast
            if lhsDate != rhsDate { return lhsDate > rhsDate }
            if lhs.nightEndingDate != rhs.nightEndingDate { return lhs.nightEndingDate > rhs.nightEndingDate }
            return lhs.receiptID.uuidString > rhs.receiptID.uuidString
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            tonight
            recentReceipts
            mosaic
        }
    }

    private var tonight: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("TONIGHT TOGETHER")
                .font(pixelFont(.caption))
                .foregroundStyle(AppColors.grass)
            if tonightPlans.isEmpty {
                SlumberPartyV4UnavailableCard(title: "No shared plan is available for tonight yet.", detail: "Missing means unknown; your personal Wind Down still works normally.")
            } else {
                ForEach(tonightPlans) { plan in
                    PixelCard {
                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            Text(memberName(plan.memberID))
                                .font(AppTypography.headline)
                            Text("Planned " + planTimeText(plan))
                                .font(AppTypography.body.weight(.semibold))
                            Text(plan.eveningSuggestionIDs.isEmpty && plan.morningSuggestionIDs.isEmpty ? "No routine ideas shared." : "Ideas are planned context, not a checklist.")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.secondaryText)
                            routineButtons(plan)
                        }
                    }
                }
            }
            if let borrowNotice { Text(borrowNotice).font(AppTypography.caption).foregroundStyle(AppColors.secondaryText) }
        }
    }

    private var recentReceipts: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("RECENT NIGHTS")
                .font(pixelFont(.caption))
                .foregroundStyle(AppColors.grass)
            if state.sharedNightReceipts.isEmpty {
                Text("No factual shared receipt yet. No update is not a missed night.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
            } else {
                ForEach(orderedRecentReceipts.prefix(8)) { receipt in
                    let plan = state.sharedNightPlans.first { $0.planID == receipt.planID && $0.revision == receipt.planRevision }
                    PixelCard {
                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            Text(memberName(receipt)).font(AppTypography.headline)
                            Text(SharedNightPresentation.receiptText(plan: plan, receipt: receipt))
                                .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                            Text(protectionText(receipt)).font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                        }
                    }
                }
            }
            if state.sharedNightsNextCursor != nil {
                Button(appViewModel.nightFlockViewModel.sharedNightsLoadingPartyIDs.contains(party.summary.partyID) ? "Loading earlier shared nights…" : "Load earlier shared nights") {
                    appViewModel.nightFlockViewModel.loadMoreSharedNights(partyID: party.summary.partyID)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .buttonStyle(PixelChipButtonStyle(isSelected: false))
                .disabled(appViewModel.nightFlockViewModel.sharedNightsLoadingPartyIDs.contains(party.summary.partyID))
            }
        }
    }

    private var mosaic: some View {
        let planBacked = SharedNightMosaicPresentation.planBackedReceipts(mosaicReceipts, plans: mosaicPlans)
        let completed = planBacked.filter { $0.outcome == .completed }.count
        let observed = planBacked.filter { $0.outcome != .unknown }.count
        let planlessFactual = mosaicReceipts.filter { receipt in
            !planBacked.contains(where: { $0.receiptID == receipt.receiptID }) && receipt.outcome != .unknown
        }.count
        return PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("SEVEN-NIGHT TOGETHER")
                    .font(pixelFont(.caption)).foregroundStyle(AppColors.grass)
                Text("\(completed) completed Wind Downs from \(observed) factual receipts")
                    .font(AppTypography.body.weight(.semibold))
                Text("Coverage: \(observed) of \(SharedNightMosaicPresentation.coverageSlotCount(for: mosaicPlans)) shared plan slots in this seven-night window. Unknown nights are not misses.")
                    .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                if planlessFactual > 0 {
                    Text("\(planlessFactual) other factual receipt\(planlessFactual == 1 ? "" : "s") did not have a shared plan to compare.")
                        .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                }
            }
        }
    }

    @ViewBuilder
    private func routineButtons(_ plan: SharedNightPlan) -> some View {
        let ideas = plan.eveningSuggestionIDs.map { ($0, WindDownRoutinePhase.evening) } + plan.morningSuggestionIDs.map { ($0, WindDownRoutinePhase.morning) }
        if !ideas.isEmpty && plan.memberID != party.myMemberID {
            ForEach(ideas, id: \.0) { idea in
                Button("Add \(PhoneFreeActivity(rawValue: idea.0)?.shortTitle ?? "this idea") to my routine") {
                    switch appViewModel.borrowSharedRoutineIdea(idea.0, phase: idea.1) {
                    case .added: borrowNotice = "Added to your private routine. It does not change what anyone else did."
                    case .alreadyAdded: borrowNotice = "That idea is already in your private routine."
                    case .needsReplacement: borrowNotice = "That part of your routine is full. Open Plan to choose what to replace."
                    case .unavailable: borrowNotice = "Save a private Wind Down plan first, then you can borrow this idea."
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .buttonStyle(PixelChipButtonStyle(isSelected: false))
            }
        }
    }

    private func memberName(_ memberID: UUID) -> String {
        party.memberships.first(where: { $0.memberID == memberID })?.profile.displayName ?? "A group member"
    }

    private func memberName(_ receipt: SharedNightReceipt) -> String {
        party.memberships.first(where: { $0.memberID == receipt.memberID })?.profile.displayName
            ?? receipt.profileSnapshot.displayName
    }

    private func date(after date: NightFlockLocalDate, in timeZoneIdentifier: String) -> NightFlockLocalDate? {
        guard let source = date.date(in: timeZoneIdentifier) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
        return calendar.date(byAdding: .day, value: 1, to: source).flatMap {
            NightFlockLocalDate(date: $0, timeZoneIdentifier: timeZoneIdentifier, calendar: calendar)
        }
    }

    private func planTimeText(_ plan: SharedNightPlan) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone(identifier: plan.timeZoneIdentifier) ?? .current
        let zone = formatter.timeZone.abbreviation() ?? plan.timeZoneIdentifier
        return "\(formatter.string(from: plan.plannedWindDownStart)) \(zone)"
    }

    private func protectionText(_ receipt: SharedNightReceipt) -> String {
        switch receipt.protectionEvidence {
        case .observed: return receipt.protectionMinutes.map { "Protection recorded for \($0) min before bed." } ?? "Protection observation unavailable."
        case .partial: return "Protection was partly observed."
        case .failedOpen: return "Protection could not stay on; the run remained factual."
        case .unavailable, .unknown: return "Protection evidence unavailable."
        }
    }
}
