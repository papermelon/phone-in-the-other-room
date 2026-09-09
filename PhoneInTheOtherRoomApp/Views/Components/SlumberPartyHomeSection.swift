import SwiftUI

/// Home's read-only Slumber Party bridge. The group list remains canonical and
/// cached details are membership-filtered by the view model before reaching
/// this surface; Home never infers a group or requests its own refresh.
struct SlumberPartyHomeSection: View {
    @ObservedObject var viewModel: NightFlockViewModel
    @Environment(\.scenePhase) private var scenePhase
    var openParty: (UUID?) -> Void
    @State private var selectedPartyID: UUID?
    @State private var selectedHighlightIDs: [UUID: SlumberPartyHomeHighlightID] = [:]
    @State private var displayDate = Date()

    private var parties: [NightFlockV4PartySummary] { viewModel.slumberParties }

    private var selectedParty: NightFlockV4PartySummary? {
        if let selectedPartyID,
           let party = parties.first(where: { $0.partyID == selectedPartyID }) {
            return party
        }
        return parties.first
    }

    private var detail: NightFlockV4PartyDetail? {
        guard let selectedParty else { return nil }
        return viewModel.v4ObservedPartyDetail(for: selectedParty.partyID)
    }

    private var displayInvalidation: Date? {
        guard let detail else { return nil }
        return [
            NightFlockV4Presentation.nextDisplayInvalidation(in: detail, at: displayDate),
            SlumberPartyHomePresentation.nextHighlightInvalidation(in: detail, at: displayDate)
        ]
        .compactMap { $0 }
        .min()
    }

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                header
                if parties.isEmpty {
                    emptyState
                } else if let selectedParty {
                    partyContent(selectedParty)
                }
            }
        }
        .task(id: displayInvalidation) {
            guard let displayInvalidation else { return }
            let delay = max(0, displayInvalidation.timeIntervalSince(Date()))
            guard delay > 0 else {
                refreshDisplayDate()
                return
            }
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            refreshDisplayDate()
        }
        .onChange(of: detail) { _, _ in
            displayDate = Date()
            reconcileHighlightSelection()
        }
        .onChange(of: parties.map(\.partyID)) { _, partyIDs in
            if let selectedPartyID, partyIDs.contains(selectedPartyID) {
                return
            } else {
                selectedPartyID = partyIDs.first
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                refreshDisplayDate()
            }
        }
        .task(id: parties.map(\.partyID)) {
            if !parties.contains(where: { $0.partyID == selectedPartyID }) {
                selectedPartyID = parties.first?.partyID
            }
            reconcileHighlightSelection()
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("SLUMBER PARTY")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                if parties.isEmpty {
                    Text("A small circle for quiet nights")
                        .font(AppTypography.headline)
                }
            }
            Spacer(minLength: AppSpacing.sm)
            if parties.count > 1 {
                partyPicker
            }
        }
    }

    private var partyPicker: some View {
        Menu {
            Picker("Slumber Party", selection: $selectedPartyID) {
                ForEach(parties) { party in
                    Text(party.name).tag(Optional(party.partyID))
                }
            }
        } label: {
            Label("Choose group", systemImage: "chevron.up.chevron.down")
                .font(AppTypography.caption.weight(.semibold))
                .foregroundStyle(AppColors.grass)
                .frame(minHeight: 44)
        }
        .accessibilityHint("Chooses one Slumber Party. Groups stay separate.")
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Start a private seven-night group, or join one with an invite code.")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Button("Start or join a group") {
                openParty(nil)
            }
            .buttonStyle(PixelChipButtonStyle(isSelected: false))
            .frame(minHeight: 44)
        }
    }

    private func partyContent(_ party: NightFlockV4PartySummary) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Button {
                openParty(party.partyID)
            } label: {
                HStack(spacing: AppSpacing.xs) {
                    Text(party.name)
                        .font(AppTypography.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: AppSpacing.xs)
                    Image(systemName: "chevron.right")
                        .font(AppTypography.caption.weight(.bold))
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(party.name)")
            .accessibilityHint("Opens the shared Farm, member updates and cheers")

            if let detail {
                memberMoments(in: detail, party: party)
                tonightTogether(partyID: party.partyID)
                highlight(in: detail)
                observationLine(for: party.partyID)
            } else {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    roundContext(for: party)
                    Text(cachePendingLine(for: party.partyID))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder
    private func tonightTogether(partyID: UUID) -> some View {
        if !viewModel.supportsSharedNightPlans {
            EmptyView()
        } else if let state = viewModel.sharedHabitsState(for: partyID) {
            if state.agreement?.agreementVersion ?? 0 < 2 {
                Text("Tonight together opens after you choose the updated sharing agreement.")
                    .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
            } else if let next = state.sharedNightPlans.filter({ $0.supersededAt == nil && $0.plannedWindDownStart >= displayDate.addingTimeInterval(-6 * 60 * 60) }).sorted(by: { $0.plannedWindDownStart < $1.plannedWindDownStart }).first {
                Text("Tonight together · \(memberName(next.memberID, in: detail)) plans Wind Down at \(next.plannedWindDownStart.formatted(date: .omitted, time: .shortened)).")
                    .font(AppTypography.caption.weight(.semibold)).foregroundStyle(AppColors.ink)
            } else {
                Text("Tonight together · No shared plan yet. No update is not a missed night.")
                    .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
            }
        } else {
            Text("Tonight together is waiting for the group’s saved summary.")
                .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
        }
    }

    private func memberName(_ id: UUID, in detail: NightFlockV4PartyDetail?) -> String {
        detail?.memberships.first(where: { $0.memberID == id })?.profile.displayName ?? "A group member"
    }

    @ViewBuilder
    private func memberMoments(
        in detail: NightFlockV4PartyDetail,
        party: NightFlockV4PartySummary
    ) -> some View {
        let previews = SlumberPartyHomePresentation.memberPreviews(in: detail, at: displayDate)
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    ForEach(previews.prefix(2)) { preview in
                        compactMember(preview, in: detail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    compactOverflow(
                        memberCount: detail.memberships.count,
                        displayedCount: min(2, previews.count)
                    )
                    if let roundTitle = activeRoundTitle(for: party) {
                        roundBadge(roundTitle)
                    }
                }
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    HStack(alignment: .top, spacing: AppSpacing.sm) {
                        ForEach(previews.prefix(2)) { preview in
                            compactMember(preview, in: detail)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        compactOverflow(
                            memberCount: detail.memberships.count,
                            displayedCount: min(2, previews.count)
                        )
                    }
                    if let roundTitle = activeRoundTitle(for: party) {
                        roundBadge(roundTitle)
                    }
                }
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    ForEach(previews) { preview in
                        compactMember(preview, in: detail)
                    }
                    compactOverflow(
                        memberCount: detail.memberships.count,
                        displayedCount: previews.count
                    )
                    if let roundTitle = activeRoundTitle(for: party) {
                        roundBadge(roundTitle)
                    }
                }
            }
            if activeRoundTitle(for: party) == nil {
                roundContext(for: party)
            }
        }
    }

    @ViewBuilder
    private func compactMember(
        _ preview: SlumberPartyHomeMemberPreview,
        in detail: NightFlockV4PartyDetail
    ) -> some View {
        if let member = detail.memberships.first(where: { $0.memberID == preview.memberID }) {
            HStack(alignment: .top, spacing: AppSpacing.xs) {
                memberAvatar(for: member)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(preview.isCurrentUser ? "You" : preview.displayName)
                        .font(AppTypography.caption.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(preview.statusTitle)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private func compactOverflow(memberCount: Int, displayedCount: Int) -> some View {
        let remaining = max(0, memberCount - displayedCount)
        if remaining > 0 {
            Text("+\(remaining)")
                .font(AppTypography.caption.weight(.semibold))
                .foregroundStyle(AppColors.grass)
                .accessibilityLabel("\(remaining) more members in this group")
        }
    }

    @ViewBuilder
    private func memberAvatar(for member: NightFlockV4Membership) -> some View {
        SlumberPartySocialAvatarView(
            presentation: member.profile.presentation,
            avatarID: member.profile.presentation.avatarID,
            size: 32
        )
        .accessibilityHidden(true)
    }

    private func roundLine(for party: NightFlockV4PartySummary) -> String {
        guard let round = party.currentRound else {
            return party.supportsMembershipSharing
                ? "\(party.memberCount) people · Share Wind Down and Phone Away moments now"
                : "\(party.memberCount) people · Shared moments begin with the next seven nights"
        }
        switch round.status {
        case .active:
            if let day = NightFlockV4RoundRules.day(at: displayDate, round: round) {
                return "Night \(day) of 7 · \(party.memberCount) people"
            }
            return "Seven nights underway · \(party.memberCount) people"
        case .pending: return party.supportsMembershipSharing ? "Sharing is open · seven nights are waiting" : "A seven-night round is waiting · \(party.memberCount) people"
        case .completed: return party.supportsMembershipSharing ? "Sharing is open · these seven nights are complete" : "These seven nights are complete · \(party.memberCount) people"
        }
    }

    @ViewBuilder
    private func roundContext(for party: NightFlockV4PartySummary) -> some View {
        if let roundTitle = activeRoundTitle(for: party) {
            roundBadge(roundTitle)
        } else {
            Text(roundLine(for: party))
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func activeRoundTitle(for party: NightFlockV4PartySummary) -> String? {
        guard let round = party.currentRound,
              round.status == .active,
              let day = NightFlockV4RoundRules.day(at: displayDate, round: round)
        else { return nil }
        return "Night \(day) of 7"
    }

    private func roundBadge(_ title: String) -> some View {
        Text(title)
            .font(AppTypography.caption)
            .foregroundStyle(AppColors.muted)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, AppSpacing.xs)
            .padding(.vertical, AppSpacing.xxs)
            .background(AppColors.grassLight.opacity(0.45), in: Capsule())
            .accessibilityLabel(title)
    }

    @ViewBuilder
    private func highlight(in detail: NightFlockV4PartyDetail) -> some View {
        let highlight = SlumberPartyHomePresentation.highlight(
            in: detail,
            preserving: selectedHighlightIDs[detail.summary.partyID],
            at: displayDate
        )
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Divider()
            Text(highlight.map { compactHighlightSentence($0) } ?? "No recent shared moments.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func compactHighlightSentence(_ highlight: SlumberPartyHomeHighlight) -> String {
        let detail = highlight.detail
            .replacingOccurrences(of: " · Recent shared moment", with: "")
            .replacingOccurrences(of: "A recent shared moment from this party.", with: "")
            .replacingOccurrences(of: "Open the group for its shared history.", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return detail.isEmpty ? highlight.title : "\(highlight.title) \(detail)"
    }

    private func reconcileHighlightSelection() {
        guard let detail else { return }
        let partyID = detail.summary.partyID
        if let highlight = SlumberPartyHomePresentation.highlight(
            in: detail,
            preserving: selectedHighlightIDs[partyID],
            at: displayDate
        ) {
            selectedHighlightIDs[partyID] = highlight.id
        } else {
            selectedHighlightIDs.removeValue(forKey: partyID)
        }
    }

    private func refreshDisplayDate() {
        displayDate = Date()
        reconcileHighlightSelection()
    }

    private func cachePendingLine(for partyID: UUID) -> String {
        switch viewModel.v4ObservedPartyObservationState(for: partyID) {
        case .refreshing: return "Checking the latest shared moments…"
        case .stale: return "Open the group to refresh its shared moments."
        case .current: return "Shared moments are ready to show."
        case .notRequested: return "Open the group to see shared moments."
        }
    }

    private func observationLine(for partyID: UUID) -> some View {
        let text: String
        switch viewModel.v4ObservedPartyObservationState(for: partyID) {
        case .refreshing: text = "Refreshing shared moments…"
        case .stale: text = "Showing the last shared moments."
        case .current, .notRequested: text = ""
        }
        return Group {
            if !text.isEmpty {
                Text(text)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
        }
    }

}
