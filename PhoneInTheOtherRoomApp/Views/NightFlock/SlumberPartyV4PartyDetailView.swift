import SwiftUI
import UIKit

struct SlumberPartyV4PartyDetailView: View {
    @ObservedObject var viewModel: NightFlockViewModel
    let summary: NightFlockV4PartySummary
    @State private var newName = ""
    @State private var showsLeaveConfirmation = false
    @State private var showsDeleteConfirmation = false
    @State private var showsBlockConfirmation = false
    @State private var memberAwaitingBlock: NightFlockV4Membership?
    @State private var copiedCodeNotice: String?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.dismiss) private var dismiss

    private var party: NightFlockV4PartyDetail? {
        guard viewModel.selectedV4Party?.summary.partyID == summary.partyID else { return nil }
        return viewModel.selectedV4Party
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                if let party {
                    partyContent(party)
                } else {
                    NightFlockStatusCard(
                        symbol: "moon.stars.fill",
                        title: "Opening this Slumber Party…",
                        detail: "Ollie is bringing the group’s shared record into view."
                    )
                    .redacted(reason: .placeholder)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxl)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle(summary.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            newName = summary.name
            viewModel.selectSlumberParty(summary.partyID)
        }
        .onChange(of: viewModel.v4ListState?.parties) { _, parties in
            guard let parties,
                  !parties.contains(where: { $0.partyID == summary.partyID }),
                  viewModel.selectedV4Party?.summary.partyID != summary.partyID
            else { return }
            dismiss()
        }
        .confirmationDialog("Leave this Slumber Party?", isPresented: $showsLeaveConfirmation) {
            Button("Leave group", role: .destructive) {
                viewModel.leaveSlumberParty(summary.partyID)
            }
        } message: {
            Text("Your local Wind Down and Farm will stay on this iPhone.")
        }
        .confirmationDialog("Delete this Slumber Party?", isPresented: $showsDeleteConfirmation) {
            Button("Delete group", role: .destructive) {
                viewModel.deleteSlumberParty(summary.partyID)
            }
        } message: {
            Text("This removes the shared group for its members. Your local Wind Down and Farm will stay on this iPhone.")
        }
        .confirmationDialog("Block this member?", isPresented: $showsBlockConfirmation) {
            Button("Block member", role: .destructive) {
                guard let memberAwaitingBlock else { return }
                viewModel.blockSlumberPartyMember(
                    partyID: summary.partyID,
                    memberID: memberAwaitingBlock.memberID
                )
                self.memberAwaitingBlock = nil
            }
        } message: {
            Text("You will be separated in shared groups and cannot join another group together.")
        }
    }

    @ViewBuilder
    private func partyContent(_ party: NightFlockV4PartyDetail) -> some View {
        partyHeader(party)
        if let copiedCodeNotice {
            Text(copiedCodeNotice)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        invitationSection(party)
        peopleSection(party)
        activitiesSection(party)
        controlsSection(party)
    }

    private func partyHeader(_ party: NightFlockV4PartyDetail) -> some View {
        PixelCard {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("SLUMBER PARTY")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text(party.summary.name)
                        .font(AppTypography.title)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(roundDescription(party.summary.currentRound))
                        .font(AppTypography.body.weight(.semibold))
                    Text("\(memberCountTitle(party.memberships.count)) · \(party.summary.myRole == .host ? "You’re hosting" : "You’re a member")")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                }
                Spacer(minLength: 0)
                Button {
                    viewModel.refreshSelectedSlumberParty()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(PixelChipButtonStyle(isSelected: false))
                .accessibilityLabel("Refresh this Slumber Party")
            }
        }
    }

    private func memberCountTitle(_ count: Int) -> String {
        count == 1 ? "1 person" : "\(count) people"
    }

    private func displayInvitationCode(_ code: String) -> String {
        code.enumerated().reduce(into: "") { formatted, item in
            if item.offset > 0, item.offset.isMultiple(of: 4) {
                formatted.append(" ")
            }
            formatted.append(item.element)
        }
    }

    @ViewBuilder
    private func invitationSection(_ party: NightFlockV4PartyDetail) -> some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("INVITATION")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                if let code = viewModel.v4InviteCode, party.invitation?.status == .active {
                    Text(displayInvitationCode(code))
                        .font(AppTypography.headline.monospaced())
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                        .accessibilityLabel("Invitation code \(code)")
                    invitationActions(code: code)
                } else if party.invitation?.status == .active {
                    Text("An invitation is active for this group.")
                        .font(AppTypography.body)
                    Button("Show active code") {
                        viewModel.retrieveSlumberPartyInvite(party.summary.partyID)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .buttonStyle(PixelChipButtonStyle(isSelected: false))
                } else if party.summary.myRole == .host {
                    Text("Invite people you know when you’re ready.")
                        .font(AppTypography.body)
                    Button("Create invitation") {
                        viewModel.createSlumberPartyInvite(party.summary.partyID)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .buttonStyle(PixelPrimaryButtonStyle())
                } else {
                    Text("The host has not shared an active invitation right now.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                }
            }
        }
    }

    @ViewBuilder
    private func invitationActions(code: String) -> some View {
        VStack(spacing: AppSpacing.xs) { invitationActionButtons(code: code) }
    }

    @ViewBuilder
    private func invitationActionButtons(code: String) -> some View {
        Button("Copy code") {
            UIPasteboard.general.string = code
            copiedCodeNotice = "Invitation code copied."
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .buttonStyle(PixelChipButtonStyle(isSelected: false))
        ShareLink(item: code, subject: Text("Slumber Party invitation")) {
            Label("Share code", systemImage: "square.and.arrow.up")
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .buttonStyle(PixelChipButtonStyle(isSelected: false))
        if party?.summary.myRole == .host, let invitation = party?.invitation {
            Button("Replace code") {
                viewModel.replaceSlumberPartyInvite(summary.partyID, expectedInviteID: invitation.inviteID)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .buttonStyle(PixelChipButtonStyle(isSelected: false))
            Button("Revoke code") {
                viewModel.revokeSlumberPartyInvite(summary.partyID, inviteID: invitation.inviteID)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .buttonStyle(PixelChipButtonStyle(isSelected: false))
        }
    }

    private func peopleSection(_ party: NightFlockV4PartyDetail) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("PEOPLE IN THIS PARTY")
                .font(pixelFont(.caption))
                .foregroundStyle(AppColors.grass)
            ForEach(party.memberships) { member in
                SlumberPartyV4MemberCard(
                    member: member,
                    isYou: member.memberID == party.myMemberID,
                    liveStatus: currentLiveStatus(for: member, in: party),
                    onBlock: {
                        memberAwaitingBlock = member
                        showsBlockConfirmation = true
                    },
                    onReport: { reason in
                        viewModel.reportSlumberPartyMember(
                            partyID: party.summary.partyID,
                            memberID: member.memberID,
                            reason: reason
                        )
                    },
                    liveCheerCount: party.liveCheers
                        .filter { $0.memberID == member.memberID }
                        .reduce(0) { $0 + $1.count },
                    onLiveCheer: { cheer in
                        viewModel.cheerSlumberPartyMember(
                            partyID: party.summary.partyID,
                            memberID: member.memberID,
                            cheer: cheer
                        )
                    }
                )
            }
        }
    }

    @ViewBuilder
    private func activitiesSection(_ party: NightFlockV4PartyDetail) -> some View {
        let currentActivities = currentActivities(in: party)
        let earlierActivities = earlierActivities(in: party)
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("THIS ROUND")
                .font(pixelFont(.caption))
                .foregroundStyle(AppColors.grass)
            if currentActivities.isEmpty {
                SlumberPartyV4UnavailableCard(
                    title: "No shared activities yet.",
                    detail: "Completed Wind Down and Phone Away records will appear here when they reach the group."
                )
            } else {
                ForEach(currentActivities) { activity in
                    activityCard(activity, in: party)
                }
            }
            if !earlierActivities.isEmpty {
                Text("EARLIER ROUNDS")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                    .padding(.top, AppSpacing.xs)
                ForEach(earlierActivities.prefix(8)) { activity in
                    activityCard(activity, in: party)
                }
            }
        }
    }

    private func activityCard(_ activity: NightFlockV4Activity, in party: NightFlockV4PartyDetail) -> some View {
        let memberName = party.memberships.first(where: { $0.memberID == activity.memberID })?.profile.displayName ?? "A group member"
        let cheers = party.cheers.filter { $0.activityID == activity.activityID }
        return PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(memberName)
                    .font(AppTypography.headline)
                Text("\(activityTitle(activity)) · \(activity.roundedMinutes) quiet minutes")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                if activity.memberID == party.myMemberID {
                    if !cheers.isEmpty {
                        Text(cheerSummary(cheers))
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondaryText)
                    }
                } else {
                    cheerButtons(activity: activity, cheers: cheers, partyID: party.summary.partyID)
                }
            }
        }
    }

    @ViewBuilder
    private func cheerButtons(
        activity: NightFlockV4Activity,
        cheers: [NightFlockV4CheerSummary],
        partyID: UUID
    ) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: AppSpacing.xs) { cheerButtonSet(activity: activity, cheers: cheers, partyID: partyID) }
        } else {
            HStack(spacing: AppSpacing.xs) { cheerButtonSet(activity: activity, cheers: cheers, partyID: partyID) }
        }
    }

    @ViewBuilder
    private func cheerButtonSet(
        activity: NightFlockV4Activity,
        cheers: [NightFlockV4CheerSummary],
        partyID: UUID
    ) -> some View {
        ForEach(NightFlockV4Cheer.allCases, id: \.self) { cheer in
            let summary = cheers.first(where: { $0.cheer == cheer })
            Button("\(cheerTitle(cheer)) \(summary?.count ?? 0)") {
                viewModel.sendSlumberPartyCheer(partyID: partyID, activityID: activity.activityID, cheer: cheer)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .buttonStyle(PixelChipButtonStyle(isSelected: summary?.sentByMe == true))
        }
    }

    @ViewBuilder
    private func controlsSection(_ party: NightFlockV4PartyDetail) -> some View {
        if party.summary.myRole == .host {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("HOST CONTROLS")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                TextField("Group name", text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.body)
                    .frame(minHeight: 44)
                Button("Save group name") {
                    viewModel.renameSlumberParty(party.summary.partyID, name: newName)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .buttonStyle(PixelChipButtonStyle(isSelected: false))
                if canStartRound(party.summary.currentRound) {
                    Button(startRoundTitle(party.summary.currentRound)) {
                        viewModel.startAnotherSevenNights(party.summary.partyID)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .buttonStyle(PixelPrimaryButtonStyle())
                    .disabled(party.memberships.count < NightFlockV4Rules.minimumMembers)
                    if party.memberships.count < NightFlockV4Rules.minimumMembers {
                        Text("Invite one more person before your seven nights begin.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Text("This seven-night round is already underway. Another can begin once it is complete.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button("Delete group", role: .destructive) {
                    showsDeleteConfirmation = true
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .buttonStyle(PixelChipButtonStyle(isSelected: false))
            }
        } else {
            Button("Leave group", role: .destructive) {
                showsLeaveConfirmation = true
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .buttonStyle(PixelChipButtonStyle(isSelected: false))
        }
    }

    private func currentLiveStatus(
        for member: NightFlockV4Membership,
        in party: NightFlockV4PartyDetail
    ) -> NightFlockV4LiveStatus? {
        guard let roundID = party.summary.currentRound?.roundID else { return nil }
        return party.liveStatuses.first {
            $0.memberID == member.memberID && $0.roundID == roundID && $0.isCurrent(at: Date())
        }
    }

    private func currentActivities(in party: NightFlockV4PartyDetail) -> [NightFlockV4Activity] {
        guard let roundID = party.summary.currentRound?.roundID else { return [] }
        return party.activities.filter { $0.roundID == roundID }.sorted { $0.occurredAt > $1.occurredAt }
    }

    private func earlierActivities(in party: NightFlockV4PartyDetail) -> [NightFlockV4Activity] {
        guard let roundID = party.summary.currentRound?.roundID else {
            return party.activities.sorted { $0.occurredAt > $1.occurredAt }
        }
        return party.activities
            .filter { $0.roundID != roundID }
            .sorted { $0.occurredAt > $1.occurredAt }
    }

    private func roundDescription(_ round: NightFlockV4Round?) -> String {
        guard let round else { return "Ready for the next seven nights" }
        switch round.status {
        case .pending: return "Round \(round.number) is ready to begin"
        case .active:
            let day = NightFlockV4RoundRules.day(at: Date(), round: round) ?? 7
            return "Round \(round.number) · Day \(day) of 7"
        case .completed: return "Round \(round.number) is complete"
        }
    }

    private func activityTitle(_ activity: NightFlockV4Activity) -> String {
        let kind = activity.kind == .windDown ? "Wind Down" : "Phone Away"
        return activity.status == .completed ? "\(kind) completed" : "\(kind) partly completed"
    }

    private func startRoundTitle(_ round: NightFlockV4Round?) -> String {
        guard let round else { return "Start seven nights" }
        switch round.status {
        case .pending: return "Start seven nights"
        case .active, .completed: return "Start another seven nights"
        }
    }

    private func canStartRound(_ round: NightFlockV4Round?) -> Bool {
        guard let round else { return true }
        switch round.status {
        case .pending, .completed:
            return true
        case .active:
            return !NightFlockV4RoundRules.isCurrent(round, at: Date())
        }
    }

    private func cheerTitle(_ cheer: NightFlockV4Cheer) -> String {
        switch cheer {
        case .warmWave: return "Warm wave"
        case .moonGlow: return "Moon glow"
        case .pawPrint: return "Paw print"
        }
    }

    private func cheerSummary(_ cheers: [NightFlockV4CheerSummary]) -> String {
        cheers.map { "\(cheerTitle($0.cheer)): \($0.count)" }.joined(separator: " · ")
    }
}
