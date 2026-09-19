import SwiftUI

struct SlumberPartyV4PartyDetailView: View {
    @ObservedObject var viewModel: NightFlockViewModel
    let summary: NightFlockV4PartySummary
    @State private var selectedFarmActivity: UUID?
    @State private var selectedFarmMember: UUID?
    @State private var showsMemberUpdates = false
    @State private var showsBlockConfirmation = false
    @State private var memberAwaitingBlock: NightFlockV4Membership?
    @State private var showsReportConfirmation = false
    @State private var memberAwaitingReport: NightFlockV4Membership?
    @State private var reportReasonAwaitingConfirmation: NightFlockReportReason?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.dismiss) private var dismiss
    @Environment(\.sharedFarmPrototype) private var sharedFarmPrototype
    @EnvironmentObject private var appViewModel: FocusRunViewModel
    @State private var suggestedGreeting: NightFlockV4Cheer?
    @State private var showsMoreFromGroup = false
    @State private var showsVisitPicker = false
    @State private var showsLantern = false
    @State private var showsCampfire = false
    @State private var selectedCampfireBuddy: CampfireBuddySession?
    @State private var joinsAfterBuddyDismissal: NightFlockV4ActivityKind?

    @ViewBuilder
    private func campfireCard(_ session: CampfireSession, party: NightFlockV4PartyDetail, date: Date) -> some View {
        if let buddy = party.pasture?.campfire?.buddies?.sessions.first(where: { $0.sourceID == session.id && $0.memberID == session.memberID }) {
            CampfireBuddyCard(session: buddy, party: party, active: true, now: date, canJoin: !appViewModel.isRunning,
                isSending: viewModel.pastureSending.contains(party.summary.partyID),
                onJoin: { _ = appViewModel.requestCampfireSessionStart(session.kind) },
                onAction: { action, outcome, note in
                    viewModel.sendCampfireAction(action, session: buddy, partyID: party.summary.partyID, outcome: outcome, reflection: note)
                })
        } else {
            Text("\(party.memberships.first { $0.memberID == session.memberID }?.profile.displayName ?? "Member") · \(session.title)")
                .font(AppTypography.body).padding(.vertical, AppSpacing.sm)
        }
    }

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
                } else if let failure = viewModel.partyRefreshFailures[summary.partyID] {
                    SlumberPartyV4UnavailableCard(
                        title: "This Slumber Party couldn’t be loaded",
                        detail: failure.detail,
                        requestID: failure.requestReference,
                        onRetry: failure.canRetry ? { viewModel.selectSlumberParty(summary.partyID) } : nil
                    )
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
        .sheet(isPresented: $showsMemberUpdates) {
            if let selectedFarmMember {
                let showsSocialAvatar = SlumberPartyReleasePresentationGate.showsSocialAvatar(
                    listState: viewModel.v4ListState, partyState: viewModel.sharedHabitsState(for: summary.partyID))
                if let sharedFarmPrototype, selectedFarmActivity == nil {
                    SlumberPartyFriendCardView(viewModel: viewModel, store: sharedFarmPrototype, partyID: summary.partyID,
                        memberID: selectedFarmMember, showsSocialAvatar: showsSocialAvatar, suggestedCheer: suggestedGreeting)
                        .environmentObject(appViewModel)
                } else {
                    SlumberPartyMemberUpdatesView(viewModel: viewModel, partyID: summary.partyID, memberID: selectedFarmMember,
                        showsSocialAvatar: showsSocialAvatar, initialActivityID: selectedFarmActivity,
                        memberContext: party.map { detail in
                            AnyView(peopleSection(detail, at: Date(), sharedHabitsState: viewModel.sharedHabitsState(for: summary.partyID),
                                showsSharedHabitMetrics: SlumberPartyReleasePresentationGate.showsSharedHabits(listState: viewModel.v4ListState,
                                    partyState: viewModel.sharedHabitsState(for: summary.partyID)), showsSocialAvatar: false,
                                memberIDs: [selectedFarmMember]))
                        })
                }
            }
        }
        .sheet(isPresented: $showsVisitPicker) {
            if let sharedFarmPrototype {
                SharedFarmVisitPickerView(store: sharedFarmPrototype).environmentObject(appViewModel)
            } else {
                SharedPastureSheepSheet(social: viewModel, partyID: summary.partyID).environmentObject(appViewModel)
            }
        }
        .sheet(item: $selectedCampfireBuddy, onDismiss: {
            if let kind = joinsAfterBuddyDismissal {
                joinsAfterBuddyDismissal = nil
                _ = appViewModel.requestCampfireSessionStart(kind)
            }
        }) { selected in
            NavigationStack {
                ScrollView {
                    if viewModel.v4ObservedPartyObservationState(for: summary.partyID).permitsLivePresence,
                       let party = viewModel.v4ObservedPartyDetail(for: summary.partyID),
                       let latest = party.pasture?.campfire?.buddies?.sessions.first(where: { $0.id == selected.id }) {
                        TimelineView(.periodic(from: .now, by: 15)) { context in
                        CampfireBuddyCard(session: latest, party: party,
                            active: !latest.ended && latest.expiresAt > context.date, now: context.date, canJoin: !appViewModel.isRunning,
                            isSending: viewModel.pastureSending.contains(summary.partyID),
                            onJoin: { joinsAfterBuddyDismissal = latest.kind; selectedCampfireBuddy = nil },
                            onAction: { action, outcome, note in
                                viewModel.sendCampfireAction(action, session: latest, partyID: summary.partyID, outcome: outcome, reflection: note)
                            }).padding()
                        }
                        SharedPastureSaveFeedback(social: viewModel, partyID: summary.partyID).padding()
                    } else { Text("This shared intention isn’t available right now. Refresh the party to check again.").padding() }
                }.background(AppColors.paper).navigationTitle("At the campfire")
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { selectedCampfireBuddy = nil } } }
            }
        }
        .sheet(isPresented: $showsCampfire) { CampfireSharingSheet(social: viewModel, partyID: summary.partyID) }
        .sheet(isPresented: $showsLantern) { SharedPastureLanternSheet(lantern: party?.pasture?.lantern) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { viewModel.refreshSelectedSlumberParty() } label: { Image(systemName: "arrow.clockwise") }
                    .accessibilityLabel("Refresh Slumber Party")
            }
        }
#if DEBUG
        .onReceive(NotificationCenter.default.publisher(for: .sharedFarmPrototypeOpenCard)) { notification in
            guard sharedFarmPrototype != nil, let memberID = notification.object as? UUID else { return }
            suggestedGreeting = (notification.userInfo?["suggested"] as? Bool) == true ? .pawPrint : nil
            selectedFarmMember = memberID
            selectedFarmActivity = nil
            showsMemberUpdates = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .sharedFarmPrototypeOpenVisitPicker)) { _ in
            guard sharedFarmPrototype != nil else { return }
            showsVisitPicker = true
        }
#endif
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
            Text("If the block is accepted, you and this person will be separated across every shared Slumber Party, lose mutual visibility, and be unable to join a party together. Blocking does not submit a safety report.")
        }
        .confirmationDialog("Send this safety report?", isPresented: $showsReportConfirmation) {
            Button("Send report") {
                guard let memberAwaitingReport, let reportReasonAwaitingConfirmation else { return }
                viewModel.reportSlumberPartyMember(
                    partyID: summary.partyID,
                    memberID: memberAwaitingReport.memberID,
                    reason: reportReasonAwaitingConfirmation
                )
                self.memberAwaitingReport = nil
                self.reportReasonAwaitingConfirmation = nil
            }
        } message: {
            Text("This sends the “\(reportReasonAwaitingConfirmation?.title ?? "selected")” reason to Counting Sheep. It does not block the member or promise a response or moderation outcome.")
        }
    }

    @ViewBuilder
    private func partyContent(_ party: NightFlockV4PartyDetail, at date: Date) -> some View {
        let presentation = NightFlockV4Presentation.detail(for: party, at: date)
        let sharedHabitsState = viewModel.sharedHabitsState(for: party.summary.partyID)
        let showsSharedHabits = SlumberPartyReleasePresentationGate.showsSharedHabits(
            listState: viewModel.v4ListState,
            partyState: sharedHabitsState
        )
        let showsSharedNightPlans = SlumberPartyReleasePresentationGate.showsSharedNightPlans(
            listState: viewModel.v4ListState,
            partyState: sharedHabitsState
        )
        let showsSocialAvatar = SlumberPartyReleasePresentationGate.showsSocialAvatar(
            listState: viewModel.v4ListState,
            partyState: sharedHabitsState
        )
        if appViewModel.isRunning {
            Button {
                NotificationCenter.default.post(name: .countingSheepShowHome, object: nil)
            } label: { Label("Back to your running session", systemImage: "moon.stars") }
                .buttonStyle(PixelChipButtonStyle(isSelected: false)).frame(minHeight: 44)
        }
        observationNotice(for: party, at: date)
        updateNotice
        if let sharedFarmPrototype {
            SlumberPartySharedMeadowView(
                party: party, showsSocialAvatar: showsSocialAvatar, store: sharedFarmPrototype,
                isWindDownActive: appViewModel.isRunning,
                onSelectMember: { memberID in
                    suggestedGreeting = nil
                    selectedFarmMember = memberID
                    selectedFarmActivity = nil
                    showsMemberUpdates = true
                },
                onGreetingCandidate: { memberID in
                    // A drop beside a friend only *offers* a greeting; the card confirms it.
                    suggestedGreeting = .pawPrint
                    selectedFarmMember = memberID
                    selectedFarmActivity = nil
                    showsMemberUpdates = true
                },
                onSendVisit: { showsVisitPicker = true }
            )
            SharedFarmForYouSection(party: party, store: sharedFarmPrototype) { memberID, activityID in
                suggestedGreeting = nil
                selectedFarmMember = memberID
                selectedFarmActivity = activityID
                showsMemberUpdates = true
            }
        } else {
            groupDetailsSection(party)
            CampfirePanel(social: viewModel, partyID: party.summary.partyID) { kind in
                NotificationCenter.default.post(name: .countingSheepShowHome, object: nil)
                _ = appViewModel.requestCampfireSessionStart(kind)
            }
            DisclosureGroup("Shared meadow") {
                SlumberPartyPastureView(party: party, visits: party.pasture?.visits ?? [],
                    arrangement: party.pasture?.arrangement, lantern: party.pasture?.lantern,
                    canArrange: party.pasture?.isSupported == true && !viewModel.pastureSending.contains(party.summary.partyID),
                    isQuiet: appViewModel.isRunning,
                    onMove: { viewModel.movePasture(partyID: party.summary.partyID, arrangement: $0) },
                    onSelect: { memberID in selectedFarmMember = memberID; selectedFarmActivity = nil; showsMemberUpdates = true },
                    onSheep: { showsVisitPicker = true }, onImprovement: { showsLantern = true },
                    refreshRevision: viewModel.pastureRefreshTokens[party.summary.partyID, default: 0], now: date, meadowOnly: true)
            }.font(AppTypography.headline).tint(AppColors.grass)
            SharedPastureSaveFeedback(social: viewModel, partyID: party.summary.partyID)
            CampfireFollowThrough(social: viewModel, party: party, now: date)
            SlumberPartyReceivedCheersSection(party: party) { memberID, activityID in
                selectedFarmMember = memberID
                selectedFarmActivity = activityID
                showsMemberUpdates = true
            }
        }
        if presentation.showsContextCard && !party.summary.supportsMembershipSharing {
            contextSection(presentation, party: party)
        }
        if party.summary.supportsMembershipSharing {
            if showsSharedNightPlans, let sharedHabitsState {
                SlumberPartySharedNightLoopSection(party: party, state: sharedHabitsState, now: date, appViewModel: appViewModel)
            }
            SlumberPartyGroupStreamView(party: party) { memberID, activityID in
                selectedFarmMember = memberID; selectedFarmActivity = activityID; showsMemberUpdates = true
            }
            DisclosureGroup("Habits and round progress", isExpanded: $showsMoreFromGroup) {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    if viewModel.supportsSharedHabits { sharedHabitsSection(for: party) }
                    roundProgressSection(presentation)
                }
            }.font(AppTypography.body).tint(AppColors.grass)
        } else {
            switch presentation.lifecycle {
            case .active:
                legacyPeopleSection(
                    party,
                    at: date,
                    sharedHabitsState: sharedHabitsState,
                    showsSharedHabits: showsSharedHabits,
                    showsSocialAvatar: showsSocialAvatar
                )
                activitiesSection(party, presentation: presentation)
            case .elapsedHost, .elapsedMember:
                activitiesSection(party, presentation: presentation)
                legacyPeopleSection(
                    party,
                    at: date,
                    sharedHabitsState: sharedHabitsState,
                    showsSharedHabits: showsSharedHabits,
                    showsSocialAvatar: showsSocialAvatar
                )
            case .needsInvite, .readyHost, .readyMember, .none, .multiple:
                legacyPeopleSection(
                    party,
                    at: date,
                    sharedHabitsState: sharedHabitsState,
                    showsSharedHabits: showsSharedHabits,
                    showsSocialAvatar: showsSocialAvatar
                )
            }
        }
        if !party.summary.supportsMembershipSharing, viewModel.supportsSharedHabits {
            sharedHabitsSection(for: party)
        }
        if sharedFarmPrototype != nil { groupDetailsSection(party) }
    }

    private func legacyPeopleSection(
        _ party: NightFlockV4PartyDetail,
        at date: Date,
        sharedHabitsState: NightFlockSharedHabitsStateResponse?,
        showsSharedHabits: Bool,
        showsSocialAvatar: Bool
    ) -> some View {
        peopleSection(
            party,
            at: date,
            sharedHabitsState: showsSharedHabits ? sharedHabitsState : nil,
            showsSharedHabitMetrics: showsSharedHabits,
            showsSocialAvatar: showsSocialAvatar
        )
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
                        Text("Wind Down together. Share a moment and send a quiet cheer.")
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
            EmptyView()
        case .stale:
            if let failure = viewModel.partyRefreshFailures[party.summary.partyID] {
                SlumberPartyV4UnavailableCard(
                    title: "Shared activity couldn’t be updated",
                    detail: failure.detail,
                    requestID: failure.requestReference,
                    onRetry: failure.canRetry ? { viewModel.refreshSelectedSlumberParty() } : nil
                )
            } else {
                Text("Showing the last shared activity. Refresh to check for more.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
            }
        case .notRequested, .current:
            EmptyView()
        }
    }

    @ViewBuilder
    private var updateNotice: some View {
        if let warmNotice = viewModel.warmNotice {
            NightFlockStatusCard(
                symbol: "checkmark.seal.fill",
                title: "Sharing update",
                detail: warmNotice
            )
        }
        if case let .error(message) = viewModel.phase {
            SlumberPartyV4UnavailableCard(
                title: viewModel.actionFailureTitle ?? "Slumber Party couldn’t complete this request",
                detail: message,
                requestID: viewModel.requestReference
            )
        }
    }

    private func peopleSection(
        _ party: NightFlockV4PartyDetail,
        at date: Date,
        sharedHabitsState: NightFlockSharedHabitsStateResponse? = nil,
        showsSharedHabitMetrics: Bool = false,
        showsSocialAvatar: Bool = false,
        memberIDs: Set<UUID>? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            if memberIDs == nil { Text("PEOPLE")
                .font(pixelFont(.caption))
                .foregroundStyle(AppColors.grass)
            }
            ForEach(party.memberships.filter { memberIDs?.contains($0.memberID) ?? true }) { member in
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
                        memberAwaitingReport = member
                        reportReasonAwaitingConfirmation = reason
                        showsReportConfirmation = true
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
                    showsSharedHabitMetrics: showsSharedHabitMetrics,
                    showsSocialAvatar: showsSocialAvatar,
                    showsActivitySummary: memberIDs == nil
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
                    Text("THIS ROUND")
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
            return "Seven nights to share together."
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
            Text("App-recorded Wind Down and Phone Away activity from these seven nights.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Text("Each entry is self-reported from the member’s iPhone to Slumber Party. It is not independently verified.")
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
                        Text("Members and settings")
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
        return [now] + (party.pasture?.campfire?.sessions.map(\.expiresAt).filter { $0 > now } ?? []) + NightFlockV4Presentation
            .displayInvalidationDates(in: party, at: now)
            .map { $0.addingTimeInterval(0.001) }
    }
}
