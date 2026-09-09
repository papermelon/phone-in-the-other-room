import SwiftUI

/// Membership sharing and the older round ledger remain visually distinct.
/// The server may return both while parties transition to the new stream.
struct SlumberPartyV4MembershipActivitiesSection: View {
    @ObservedObject var viewModel: NightFlockViewModel
    let party: NightFlockV4PartyDetail
    let membershipActivities: [NightFlockV4SharedActivity]
    let legacyRoundActivities: [NightFlockV4Activity]
    var compact = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            if compact {
                ForEach(membershipActivities) { membershipActivityCard($0) }
                ForEach(legacyRoundActivities) { legacyActivityCard($0) }
            } else { membershipMoments }
            if !compact && !legacyRoundActivities.isEmpty {
                legacyRoundHistory
            }
        }
    }

    private var membershipMoments: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("RECENT SHARED MOMENTS")
                .font(pixelFont(.caption))
                .foregroundStyle(AppColors.grass)
            Text("Factual Wind Down and Phone Away moments shared in this invited group. Up to 100 recent moments from the last 90 days are shown.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            if membershipActivities.isEmpty {
                SlumberPartyV4UnavailableCard(
                    title: "No shared update yet.",
                    detail: "People can share from the moment they join. No update does not tell you whether anyone took part."
                )
            } else {
                ForEach(membershipActivities.prefix(8)) { activity in
                    membershipActivityCard(activity)
                }
                if membershipActivities.count > 8 {
                    DisclosureGroup("All recent shared moments (\(membershipActivities.count))") {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            ForEach(membershipActivities.dropFirst(8)) { activity in
                                membershipActivityCard(activity)
                            }
                        }
                        .padding(.top, AppSpacing.sm)
                    }
                    .font(AppTypography.body)
                }
            }
        }
    }

    private var legacyRoundHistory: some View {
        DisclosureGroup("Round history") {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Earlier round-only records stay here while this party moves to membership sharing.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(legacyRoundActivities) { activity in
                    legacyActivityCard(activity)
                }
            }
            .padding(.top, AppSpacing.sm)
        }
        .font(AppTypography.body)
    }

    private func membershipActivityCard(_ activity: NightFlockV4SharedActivity) -> some View {
        let cheers = party.sharedCheers.filter { $0.activityID == activity.activityID }
        return activityCard(
            activityID: activity.activityID,
            occurredAt: activity.occurredAt,
            memberID: activity.memberID,
            status: activity.status,
            presentation: NightFlockV4Presentation.activityPresentation(for: activity),
            cheers: cheers,
            target: .membershipActivity(activity.activityID),
            onCheer: { cheer in
                viewModel.sendMembershipSlumberPartyCheer(
                    partyID: party.summary.partyID,
                    activityID: activity.activityID,
                    cheer: cheer
                )
            }
        )
    }

    private func legacyActivityCard(_ activity: NightFlockV4Activity) -> some View {
        let cheers = party.cheers.filter { $0.activityID == activity.activityID }
        return activityCard(
            activityID: activity.activityID,
            occurredAt: activity.occurredAt,
            memberID: activity.memberID,
            status: activity.status,
            presentation: NightFlockV4Presentation.activityPresentation(for: activity),
            cheers: cheers,
            target: .activity(activity.activityID),
            onCheer: { cheer in
                viewModel.sendSlumberPartyCheer(
                    partyID: party.summary.partyID,
                    activityID: activity.activityID,
                    cheer: cheer
                )
            }
        )
    }

    private func activityCard(
        activityID: UUID,
        occurredAt: Date,
        memberID: UUID,
        status: NightFlockV4ActivityStatus,
        presentation: NightFlockV4ActivityPresentation,
        cheers: [NightFlockV4CheerSummary],
        target: NightFlockV4CheerTarget,
        onCheer: @escaping (NightFlockV4Cheer) -> Void
    ) -> some View {
        let isYou = memberID == party.myMemberID
        return PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(memberName(for: memberID))
                    .font(AppTypography.headline)
                Text(occurredAt, format: .dateTime.day().month().year())
                    .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                Text(presentation.cardSummary)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                Text(presentation.cardState)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                if isYou, !cheers.isEmpty {
                    Text(cheerSummary(cheers))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.grass)
                } else if !isYou {
                    Text("Send a quiet cheer")
                        .font(AppTypography.caption.weight(.semibold))
                        .foregroundStyle(AppColors.ink)
                    cheerControls(target: target, cheers: cheers, onCheer: onCheer)
                    if NightFlockV4Cheer.allCases.contains(where: { cheer in
                        viewModel.v4CheerSendState(for: .init(partyID: party.summary.partyID, target: target, cheer: cheer)) == .failed
                    }) {
                        Text("Your cheer isn’t confirmed. It’s safe to retry.")
                            .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                    }
                    Text(party.updateCheerReceiptVersion == 1
                        ? "Accepted means saved by Slumber Party. App received means it reached their app; it doesn’t mean they saw it."
                        : "Accepted means saved by Slumber Party. This server doesn’t confirm receipt by their app.")
                        .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                }
                SlumberPartyUpdateCheerReceiptsView(viewModel: viewModel, party: party, activityID: activityID)
            }
        }
    }

    @ViewBuilder
    private func cheerControls(
        target: NightFlockV4CheerTarget,
        cheers: [NightFlockV4CheerSummary],
        onCheer: @escaping (NightFlockV4Cheer) -> Void
    ) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: AppSpacing.xs) { cheerButtons(target: target, cheers: cheers, onCheer: onCheer) }
        } else {
            HStack(spacing: AppSpacing.xs) { cheerButtons(target: target, cheers: cheers, onCheer: onCheer) }
        }
    }

    @ViewBuilder
    private func cheerButtons(
        target: NightFlockV4CheerTarget,
        cheers: [NightFlockV4CheerSummary],
        onCheer: @escaping (NightFlockV4Cheer) -> Void
    ) -> some View {
        ForEach(NightFlockV4Cheer.allCases, id: \.self) { cheer in
            let summary = cheers.first(where: { $0.cheer == cheer })
            let key = NightFlockV4CheerCommandKey(partyID: party.summary.partyID, target: target, cheer: cheer)
            let state = viewModel.v4CheerSendState(for: key)
            let sent = summary?.sentByMe == true || state == .sent
            Button(cheerButtonTitle(cheer, count: summary?.count ?? 0, state: state, sent: sent)) {
                guard !sent, state != .pending else { return }
                onCheer(cheer)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .buttonStyle(PixelChipButtonStyle(isSelected: sent))
            .disabled(sent || state == .pending)
            .accessibilityLabel("\(cheerTitle(cheer)), \(cheerButtonTitle(cheer, count: summary?.count ?? 0, state: state, sent: sent))")
        }
    }

    private func memberName(for memberID: UUID) -> String {
        party.memberships.first(where: { $0.memberID == memberID })?.profile.displayName ?? "A group member"
    }

    private func cheerButtonTitle(
        _ cheer: NightFlockV4Cheer,
        count: Int,
        state: NightFlockV4CheerSendState?,
        sent: Bool
    ) -> String {
        if state == .pending { return "Pending…" }
        if sent { return "Accepted" }
        if state == .failed { return "Try again" }
        return "\(cheerTitle(cheer)) \(count)"
    }

    private func cheerSummary(_ cheers: [NightFlockV4CheerSummary]) -> String {
        cheers.map { "\(cheerTitle($0.cheer)): \($0.count)" }.joined(separator: " · ")
    }

    private func cheerTitle(_ cheer: NightFlockV4Cheer) -> String {
        switch cheer {
        case .warmWave: return "Warm wave"
        case .moonGlow: return "Moon glow"
        case .pawPrint: return "Paw print"
        }
    }
}

#Preview("Received cheer") {
    let partyID = UUID()
    let memberID = UUID()
    let activity = NightFlockV4SharedActivity(
        activityID: UUID(), partyID: partyID, memberID: memberID,
        roundID: nil, day: nil, kind: .phoneAway, status: .partlyCompleted,
        roundedMinutes: 24, occurredAt: .now, mySourceEventID: UUID()
    )
    let party = NightFlockV4PartyDetail(
        summary: .init(partyID: partyID, name: "Moonfield", memberCount: 1, myRole: .host, currentRound: nil, revision: 1, sharingScope: .membership),
        myMemberID: memberID,
        memberships: [.init(memberID: memberID, profile: .init(displayName: "Clover"), role: .host, joinedAt: .now)],
        sharedCheers: [.init(activityID: activity.activityID, cheer: .warmWave, count: 2, sentByMe: false)]
    )
    SlumberPartyV4MembershipActivitiesSection(
        viewModel: NightFlockViewModel(featureEnabled: false),
        party: party,
        membershipActivities: [activity],
        legacyRoundActivities: []
    )
    .padding()
    .background(AppColors.paper)
}

#Preview("No shared moments") {
    SlumberPartyV4MembershipActivitiesSection(
        viewModel: NightFlockViewModel(featureEnabled: false),
        party: .init(summary: .init(partyID: UUID(), name: "Moonfield", memberCount: 1, myRole: .host, currentRound: nil, revision: 1, sharingScope: .membership)),
        membershipActivities: [],
        legacyRoundActivities: []
    )
    .padding()
    .background(AppColors.paper)
}
