import SwiftUI

struct SlumberPartyV4PartyDetailView: View {
    @ObservedObject var viewModel: NightFlockViewModel
    let summary: NightFlockV4PartySummary
    @State private var showsBlockConfirmation = false
    @State private var memberAwaitingBlock: NightFlockV4Membership?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appViewModel: FocusRunViewModel

    private var sharedHabitsHealthActionTitle: String? {
        switch appViewModel.healthSleepConnectionPresentation {
        case .connect: return "Connect Apple Health"
        case .dataAvailable, .noData, .staleData: return "Refresh Apple Health"
        case .unavailable, .checking: return nil
        }
    }

    private var sharedHabitsHealthAction: (() -> Void)? {
        switch appViewModel.healthSleepConnectionPresentation {
        case .connect: return { appViewModel.connectAppleHealthSleep() }
        case .dataAvailable, .noData, .staleData: return { appViewModel.refreshSleepSummary() }
        case .unavailable, .checking: return nil
        }
    }

    private var party: NightFlockV4PartyDetail? {
        viewModel.v4ObservedPartyDetail(for: summary.partyID)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                if let party {
                    SlumberPartyV4PresentationClock(party: party) { date in
                        partyContent(party, at: date)
                    }
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
        .onAppear { viewModel.selectSlumberParty(summary.partyID) }
        .onChange(of: viewModel.v4ListState?.parties) { _, parties in
            guard let parties,
                  !parties.contains(where: { $0.partyID == summary.partyID })
            else { return }
            viewModel.clearSelectedSlumberParty()
            dismiss()
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
    private func partyContent(_ party: NightFlockV4PartyDetail, at date: Date) -> some View {
        let presentation = NightFlockV4Presentation.detail(for: party, at: date)
        partyHeader(party, at: date)
        observationNotice(for: party, at: date)
        if presentation.showsContextCard && !party.summary.supportsMembershipSharing {
            contextSection(presentation, party: party)
        }
        if party.summary.supportsMembershipSharing {
            let sharedHabitsState = viewModel.sharedHabitsState(for: party.summary.partyID)
            if viewModel.supportsSharedNightPlans,
               let sharedHabitsState,
               sharedHabitsState.agreement?.agreementVersion == 2 {
                SlumberPartySharedNightLoopSection(
                    party: party,
                    state: sharedHabitsState,
                    now: date,
                    appViewModel: appViewModel
                )
            }
            peopleSection(party, at: date, sharedHabitsState: sharedHabitsState)
            if sharedHabitsState?.agreement == nil {
                sharedHabitsSection(for: party)
            }
            SlumberPartyV4MembershipActivitiesSection(
                viewModel: viewModel,
                party: party,
                membershipActivities: NightFlockV4Presentation.membershipActivitiesForPresentation(in: party, at: date),
                legacyRoundActivities: NightFlockV4Presentation.legacyRoundHistoryActivities(in: party)
            )
            if sharedHabitsState?.agreement != nil {
                sharedHabitsSection(for: party)
            }
            roundProgressSection(presentation)
        } else { switch presentation.lifecycle {
        case .needsInvite:
            peopleSection(party, at: date)
        case .readyHost, .readyMember:
            peopleSection(party, at: date)
        case .active:
            peopleSection(party, at: date)
            activitiesSection(party, presentation: presentation)
        case .elapsedHost, .elapsedMember:
            activitiesSection(party, presentation: presentation)
            peopleSection(party, at: date)
        case .none, .multiple:
            peopleSection(party, at: date)
        } }
        if !party.summary.supportsMembershipSharing {
            sharedHabitsSection(for: party)
        }
        groupDetailsSection(party)
    }

    private func contextSection(
        _ presentation: NightFlockV4DetailPresentation,
        party: NightFlockV4PartyDetail
    ) -> some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(presentation.contextTitle)
                    .font(AppTypography.headline)
                Text(presentation.contextDetail)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if let hostActionTitle = presentation.hostActionTitle {
                    Button(hostActionTitle) {
                        viewModel.startAnotherSevenNights(party.summary.partyID)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .buttonStyle(PixelPrimaryButtonStyle())
                }
            }
        }
    }

    private func partyHeader(_ party: NightFlockV4PartyDetail, at date: Date) -> some View {
        let presentation = NightFlockV4Presentation.detail(for: party, at: date)
        return PixelCard {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("SLUMBER PARTY")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text(party.summary.name)
                        .font(AppTypography.title)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(presentation.headerStateTitle)
                        .font(AppTypography.body.weight(.semibold))
                    if party.summary.supportsMembershipSharing {
                        Text("Share Wind Down and Phone Away moments with this invited group at any time.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                Button {
                    viewModel.refreshSelectedSlumberParty()
                } label: {
                    Group {
                        if viewModel.isRefreshingV4Party(party.summary.partyID) {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .frame(width: 44, height: 44)
                    .background(AppColors.surfaceMuted, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isRefreshingV4Party(party.summary.partyID))
                .accessibilityLabel("Refresh this Slumber Party")
                .accessibilityValue(viewModel.isRefreshingV4Party(party.summary.partyID) ? "Refreshing" : "")
            }
        }
    }

    @ViewBuilder
    private func observationNotice(for party: NightFlockV4PartyDetail, at date: Date) -> some View {
        switch viewModel.v4ObservedPartyObservationState(for: party.summary.partyID) {
        case .refreshing:
            Text("Refreshing the latest shared activity…")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
        case let .stale(lastReceivedAt):
            Text(lastReceivedAt == nil
                 ? "Shared activity could not be refreshed yet."
                 : "The latest shared record could not be refreshed; this may be out of date.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
        case .notRequested, .current:
            EmptyView()
        }
    }

    private func peopleSection(
        _ party: NightFlockV4PartyDetail,
        at date: Date,
        sharedHabitsState: NightFlockSharedHabitsStateResponse? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("PEOPLE")
                .font(pixelFont(.caption))
                .foregroundStyle(AppColors.grass)
            ForEach(party.memberships) { member in
                let memberPresentation = NightFlockV4Presentation.member(member, in: party, at: date)
                SlumberPartyV4MemberCard(
                    member: member,
                    isYou: member.memberID == party.myMemberID,
                    presentation: memberPresentation,
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
                    onLiveCheer: { cheer in
                        guard let observedAt = memberPresentation.liveStatusObservedAt else { return }
                        if let statusID = memberPresentation.liveStatusID {
                            viewModel.cheerMembershipSlumberPartyMember(partyID: party.summary.partyID, memberID: member.memberID, statusID: statusID, cheer: cheer)
                        } else {
                            viewModel.cheerSlumberPartyMember(partyID: party.summary.partyID, memberID: member.memberID, observedStatusAt: observedAt, cheer: cheer)
                        }
                    },
                    liveCheerState: { cheer in
                        guard let observedAt = memberPresentation.liveStatusObservedAt else { return nil }
                        return viewModel.v4CheerSendState(for: NightFlockV4CheerCommandKey(
                            partyID: party.summary.partyID,
                            target: memberPresentation.liveStatusID.map(NightFlockV4CheerTarget.membershipStatus) ?? .member(member.memberID, observedAt: observedAt),
                            cheer: cheer
                        ))
                    },
                    sharedSleepSummary: sharedHabitSummary(
                        for: member.memberID, kind: .sleep, in: sharedHabitsState
                    ),
                    sharedWindDownSummary: sharedHabitSummary(
                        for: member.memberID, kind: .windDown, in: sharedHabitsState
                    ),
                    sharedSleepWeekSummary: sharedHabitSummary(
                        for: member.memberID, kind: .sleep, period: .last7Nights, in: sharedHabitsState
                    ),
                    sharedSleepMonthSummary: sharedHabitSummary(
                        for: member.memberID, kind: .sleep, period: .last30Nights, in: sharedHabitsState
                    ),
                    sharedSleepUpdatesAfterNoon: true,
                    showsSharedHabitMetrics: party.summary.supportsMembershipSharing
                )
            }
        }
    }

    private func sharedHabitsSection(for party: NightFlockV4PartyDetail) -> some View {
        SlumberPartySharedHabitsSection(
            viewModel: viewModel,
            partyID: party.summary.partyID,
            partyName: party.summary.name,
            members: party.memberships,
            myMemberID: party.myMemberID,
            healthActionTitle: sharedHabitsHealthActionTitle,
            onHealthAction: sharedHabitsHealthAction
        )
    }

    private func sharedHabitSummary(
        for memberID: UUID,
        kind: NightFlockSharedHabitKind,
        period: NightFlockSharedHabitPeriodSummary.Period = .lastNight,
        in state: NightFlockSharedHabitsStateResponse?
    ) -> NightFlockSharedHabitPeriodSummary? {
        state?.periods.first {
            $0.memberID == memberID && $0.kind == kind && $0.period == period
        }
    }

    @ViewBuilder
    private func roundProgressSection(_ presentation: NightFlockV4DetailPresentation) -> some View {
        if presentation.lifecycle != .needsInvite {
            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("SEVEN-NIGHT PROGRESS")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text(presentation.lifecycle.listStateTitle)
                        .font(AppTypography.body.weight(.semibold))
                    Text(roundProgressDetail(for: presentation.lifecycle))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                    if roundProgressShowsRecap(for: presentation.lifecycle) {
                        Text(presentation.sharedMomentRecap)
                            .font(AppTypography.caption.weight(.semibold))
                            .foregroundStyle(AppColors.ink)
                    }
                    if let action = presentation.hostActionTitle {
                        Button(action) { viewModel.startAnotherSevenNights(summary.partyID) }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .buttonStyle(PixelChipButtonStyle(isSelected: false))
                    }
                }
            }
        }
    }

    private func roundProgressDetail(for lifecycle: NightFlockV4PresentationLifecycle) -> String {
        switch lifecycle {
        case .readyHost:
            return "No seven-night round is running. Starting one organizes progress and rewards; sharing stays open either way."
        case .readyMember:
            return "No seven-night round is running. Sharing stays open while the group decides when to begin another."
        case .active:
            return "This seven-night round organizes progress and rewards."
        case .elapsedHost, .elapsedMember:
            return "The last seven-night round is complete. Sharing stays open between rounds."
        case .needsInvite, .none, .multiple:
            return ""
        }
    }

    private func roundProgressShowsRecap(for lifecycle: NightFlockV4PresentationLifecycle) -> Bool {
        switch lifecycle {
        case .active, .elapsedHost, .elapsedMember:
            return true
        case .needsInvite, .readyHost, .readyMember, .none, .multiple:
            return false
        }
    }

    @ViewBuilder
    private func activitiesSection(
        _ party: NightFlockV4PartyDetail,
        presentation: NightFlockV4DetailPresentation
    ) -> some View {
        let currentActivities = NightFlockV4Presentation.currentRoundActivities(in: party)
        let earlierActivities = NightFlockV4Presentation.earlierActivities(in: party)
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("SHARED MOMENTS")
                .font(pixelFont(.caption))
                .foregroundStyle(AppColors.grass)
            Text("Factual Wind Down and Phone Away activity from these 7 nights.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            if currentActivities.isEmpty {
                SlumberPartyV4UnavailableCard(
                    title: "No shared update yet.",
                    detail: "No shared moment has reached this party yet. This does not tell you whether anyone took part."
                )
            } else {
                ForEach(currentActivities) { activity in
                    activityCard(activity, in: party)
                }
            }
            if !earlierActivities.isEmpty {
                DisclosureGroup("Earlier shared moments") {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        ForEach(earlierActivities.prefix(8)) { activity in
                            activityCard(activity, in: party)
                        }
                    }
                    .padding(.top, AppSpacing.sm)
                }
                .font(AppTypography.body)
            }
        }
    }

    private func activityCard(_ activity: NightFlockV4Activity, in party: NightFlockV4PartyDetail) -> some View {
        let memberName = party.memberships.first(where: { $0.memberID == activity.memberID })?.profile.displayName ?? "A group member"
        let cheers = party.cheers.filter { $0.activityID == activity.activityID }
        let presentation = NightFlockV4Presentation.activityPresentation(for: activity)
        return PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(memberName)
                    .font(AppTypography.headline)
                Text(presentation.cardSummary)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                Text(presentation.cardState)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                if activity.memberID == party.myMemberID {
                    if !cheers.isEmpty {
                        Text(cheerSummary(cheers))
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondaryText)
                    }
                } else if activity.status == .completed {
                    Text("Send a quiet cheer")
                        .font(AppTypography.caption.weight(.semibold))
                        .foregroundStyle(AppColors.ink)
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
            let key = NightFlockV4CheerCommandKey(
                partyID: partyID,
                target: .activity(activity.activityID),
                cheer: cheer
            )
            let sendState = viewModel.v4CheerSendState(for: key)
            let sent = summary?.sentByMe == true || sendState == .sent
            let pending = sendState == .pending
            Button(activityCheerTitle(cheer, count: summary?.count ?? 0, state: sendState, sent: sent)) {
                guard !sent, !pending else { return }
                viewModel.sendSlumberPartyCheer(partyID: partyID, activityID: activity.activityID, cheer: cheer)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .buttonStyle(PixelChipButtonStyle(isSelected: sent))
            .disabled(sent || pending)
        }
    }

    private func activityCheerTitle(
        _ cheer: NightFlockV4Cheer,
        count: Int,
        state: NightFlockV4CheerSendState?,
        sent: Bool
    ) -> String {
        if state == .pending { return "Sending…" }
        if sent { return "Sent" }
        if state == .failed { return "Try again" }
        return "\(cheerTitle(cheer)) \(count)"
    }

    private func groupDetailsSection(_ party: NightFlockV4PartyDetail) -> some View {
        NavigationLink {
            SlumberPartyV4GroupDetailsView(viewModel: viewModel, party: party)
        } label: {
            PixelCard {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "person.3.fill")
                        .foregroundStyle(AppColors.grass)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text("Group details")
                            .font(AppTypography.headline)
                        Text("People, invitations, and group controls")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondaryText)
                    }
                    Spacer(minLength: AppSpacing.sm)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.grass)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 44)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens people, invitations, and group controls")
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

/// Re-renders at the next known status expiry. It intentionally does not make
/// a network request, so an open screen can stop presenting a live state even
/// when the app stays in the foreground.
private struct SlumberPartyV4PresentationClock<Content: View>: View {
    let party: NightFlockV4PartyDetail
    let content: (Date) -> Content

    init(
        party: NightFlockV4PartyDetail,
        @ViewBuilder content: @escaping (Date) -> Content
    ) {
        self.party = party
        self.content = content
    }

    var body: some View {
        TimelineView(.explicit(invalidationDates)) { context in
            content(context.date)
        }
    }

    private var invalidationDates: [Date] {
        let now = Date()
        // A status is current while `expiresAt > date`, so advance one small
        // representable interval beyond the boundary rather than retaining it
        // on an exactly-equal Timeline tick. Including `now` is essential:
        // an explicit Timeline otherwise supplies its first scheduled future
        // date as the initial context, which would make every live status look
        // expired on first render.
        return [now] + NightFlockV4Presentation
            .displayInvalidationDates(in: party, at: now)
            .map { $0.addingTimeInterval(0.001) }
    }
}
