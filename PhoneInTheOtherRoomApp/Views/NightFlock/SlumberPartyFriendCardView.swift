import SwiftUI

/// Prototype card opened by tapping a character on the shared meadow. For a
/// friend it answers three questions in order: what did they share, what can
/// I send, and what exactly will they receive. For me it shows what arrived.
struct SlumberPartyFriendCardView: View {
    @ObservedObject var viewModel: NightFlockViewModel
    @ObservedObject var store: SharedFarmPrototypeStore
    let partyID: UUID
    let memberID: UUID
    var showsSocialAvatar: Bool
    var suggestedCheer: NightFlockV4Cheer? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.calendar) private var calendar
    @State private var pendingCheer: NightFlockV4Cheer?
    @State private var showsAllUpdates = false
    @State private var showsVisitPicker = false

    private var party: NightFlockV4PartyDetail? { viewModel.v4ObservedPartyDetail(for: partyID) }
    private var member: NightFlockV4Membership? { party?.memberships.first { $0.memberID == memberID } }
    private var isMe: Bool { party?.myMemberID == memberID }
    private var latestUpdate: NightFlockV4SharedActivity? {
        party.flatMap { SlumberPartySharedFarmRules.updates(for: memberID, in: $0).first }
    }
    private var greetingContext: SharedFarmGreetingContext {
        latestUpdate.map { .update(activityID: $0.activityID) } ?? .meadow
    }
    private var contextTitle: String? {
        latestUpdate.map { SharedFarmSocialCopy.relativeNight($0.occurredAt, now: store.now(), calendar: calendar) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    if let member {
                        portrait(member)
                        latestSection(member)
                        if isMe {
                            receivedSection
                            myVisitSection
                        } else {
                            greetingSection(member)
                            visitLine(member)
                        }
                        Button("All shared updates") { showsAllUpdates = true }
                            .buttonStyle(PixelChipButtonStyle(isSelected: false))
                            .frame(minHeight: 44)
                    } else {
                        SlumberPartyV4UnavailableCard(title: "This member is unavailable",
                            detail: "The party’s membership may have changed. Return to the group to refresh.")
                    }
                }
                .padding(AppSpacing.md)
                .padding(.bottom, AppSpacing.xxl)
            }
            .background(AppColors.paper.ignoresSafeArea())
            .navigationTitle(isMe ? "You" : member?.profile.displayName ?? "Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $showsAllUpdates) {
                SlumberPartyMemberUpdatesView(viewModel: viewModel, partyID: partyID, memberID: memberID, showsSocialAvatar: showsSocialAvatar)
            }
            .sheet(isPresented: $showsVisitPicker) {
                SharedFarmVisitPickerView(store: store)
            }
            .onAppear { pendingCheer = suggestedCheer }
        }
    }

    // MARK: Sections

    private func portrait(_ member: NightFlockV4Membership) -> some View {
        let avatar = showsSocialAvatar ? member.profile.presentation.avatarID : "shepherd"
        return HStack(spacing: AppSpacing.md) {
            SlumberPartySocialAvatarView(presentation: member.profile.presentation, avatarID: avatar, size: 72)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(member.profile.displayName)
                    .font(AppTypography.title)
                Text(member.role == .host ? "Hosting this party" : "In this party")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                if let visit = store.visit(from: memberID) {
                    Text(SharedFarmSocialCopy.visitLine(sheepName: visit.sheepDisplayName, ownerName: member.profile.displayName,
                                                        isMe: isMe, nightsRemaining: visit.nightsRemaining(at: store.now())))
                        .font(AppTypography.caption.weight(.semibold))
                        .foregroundStyle(AppColors.grass)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func latestSection(_ member: NightFlockV4Membership) -> some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(isMe ? "YOUR LATEST" : "THEIR LATEST")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                if let update = latestUpdate {
                    Text(SharedFarmSocialCopy.updateLine(kind: update.kind, status: update.status, roundedMinutes: update.roundedMinutes,
                                                         occurredAt: update.occurredAt, now: store.now(), calendar: calendar))
                        .font(AppTypography.body.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("App-recorded on their iPhone and shared with this party. Minutes are rounded.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("No shared update yet")
                        .font(AppTypography.body.weight(.semibold))
                    Text("A missing update doesn’t tell us whether \(isMe ? "you" : member.profile.displayName) took part.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func greetingSection(_ member: NightFlockV4Membership) -> some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("SEND A QUIET GREETING")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                Text(contextTitle.map { "For \($0)" } ?? "On the shared Farm")
                    .font(AppTypography.headline)
                cheerButtons(for: member)
                if let pendingCheer, store.greeting(from: store.myMemberID, cheer: pendingCheer, context: greetingContext, to: memberID) == nil {
                    confirmPanel(pendingCheer, member: member)
                }
                let sent = store.greetingsSent(to: memberID).filter { $0.context == greetingContext }
                ForEach(sent) { greeting in
                    deliveryRow(greeting, member: member)
                }
                Text("They see your name and the greeting beside that night. There is no read receipt, and nothing about your Farm or schedule travels with it.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func cheerButtons(for member: NightFlockV4Membership) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppSpacing.xs) { ForEach(NightFlockV4Cheer.allCases, id: \.self) { cheerButton($0) } }
            VStack(spacing: AppSpacing.xs) { ForEach(NightFlockV4Cheer.allCases, id: \.self) { cheerButton($0) } }
        }
    }

    private func cheerButton(_ cheer: NightFlockV4Cheer) -> some View {
        let existing = store.greeting(from: store.myMemberID, cheer: cheer, context: greetingContext, to: memberID)
        let isSent = existing != nil && existing?.delivery != .failed
        return Button {
            withAnimation(reduceMotion ? nil : AppMotion.stateChange) {
                pendingCheer = pendingCheer == cheer ? nil : cheer
            }
        } label: {
            VStack(spacing: AppSpacing.xxs) {
                Image(systemName: isSent ? "checkmark.circle.fill" : SharedFarmSocialCopy.cheerSymbol(cheer))
                    .font(AppTypography.headline)
                Text(SharedFarmSocialCopy.cheerTitle(cheer))
                    .font(AppTypography.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(PixelChipButtonStyle(isSelected: pendingCheer == cheer || isSent))
        .disabled(isSent)
        .accessibilityLabel("\(SharedFarmSocialCopy.cheerTitle(cheer))\(isSent ? ", sent" : "")")
        .accessibilityHint(isSent ? "Already sent for this night" : "Shows what will be sent before anything leaves your phone")
    }

    private func confirmPanel(_ cheer: NightFlockV4Cheer, member: NightFlockV4Membership) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(SharedFarmSocialCopy.senderPreview(cheer: cheer, recipientName: member.profile.displayName, contextTitle: contextTitle))
                .font(AppTypography.body)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: AppSpacing.sm) {
                Button("Send \(SharedFarmSocialCopy.cheerTitle(cheer).lowercased())") {
                    store.sendGreeting(to: memberID, cheer: cheer, context: greetingContext)
                    withAnimation(reduceMotion ? nil : AppMotion.stateChange) { pendingCheer = nil }
                }
                .buttonStyle(PixelPrimaryButtonStyle())
                .frame(maxWidth: .infinity, minHeight: 44)
                Button("Not now") { withAnimation(reduceMotion ? nil : AppMotion.stateChange) { pendingCheer = nil } }
                    .buttonStyle(PixelChipButtonStyle(isSelected: false))
                    .frame(minHeight: 44)
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.md))
        .transition(.opacity)
    }

    private func deliveryRow(_ greeting: SharedFarmGreeting, member: NightFlockV4Membership) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: SharedFarmSocialCopy.cheerSymbol(greeting.cheer))
                .foregroundStyle(AppColors.grass)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(SharedFarmSocialCopy.cheerTitle(greeting.cheer)) · \(greeting.delivery.title)")
                    .font(AppTypography.caption.weight(.semibold))
                Text(greeting.sentAt.formatted(date: .abbreviated, time: .shortened))
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
            }
            Spacer(minLength: AppSpacing.xs)
            if greeting.delivery == .pending {
                if reduceMotion { Image(systemName: "arrow.clockwise") } else { ProgressView() }
            } else if greeting.delivery == .failed {
                Button("Retry") { store.retry(greeting) }
                    .buttonStyle(PixelChipButtonStyle(isSelected: false))
                    .frame(minHeight: 44)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func visitLine(_ member: NightFlockV4Membership) -> some View {
        Group {
            if store.visit(from: memberID) == nil {
                Text("\(member.profile.displayName) hasn’t sent a sheep to visit. That’s not a missed night.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var receivedSection: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("FOR YOU")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                let received = store.greetingsReceived
                if received.isEmpty {
                    Text("No greetings yet. Friends can send one from your character on the shared Farm.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(received) { greeting in
                        HStack(alignment: .top, spacing: AppSpacing.xs) {
                            Image(systemName: SharedFarmSocialCopy.cheerSymbol(greeting.cheer))
                                .foregroundStyle(AppColors.grass)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(SharedFarmSocialCopy.recipientLine(cheer: greeting.cheer, senderName: store.displayName(for: greeting.senderMemberID),
                                                                        contextTitle: receivedContextTitle(greeting)))
                                    .font(AppTypography.body)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(greeting.sentAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.secondaryText)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    private func receivedContextTitle(_ greeting: SharedFarmGreeting) -> String? {
        guard case .update(let activityID) = greeting.context, let party,
              let update = SlumberPartySharedFarmRules.updates(for: memberID, in: party).first(where: { $0.activityID == activityID })
        else { return nil }
        return SharedFarmSocialCopy.relativeNight(update.occurredAt, now: store.now(), calendar: calendar)
    }

    private var myVisitSection: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("YOUR VISITING SHEEP")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                if let visit = store.myVisit {
                    Text(SharedFarmSocialCopy.visitLine(sheepName: visit.sheepDisplayName, ownerName: "You", isMe: true,
                                                        nightsRemaining: visit.nightsRemaining(at: store.now())))
                        .font(AppTypography.body.weight(.semibold))
                    HStack(spacing: AppSpacing.sm) {
                        Button("Send a different sheep") { showsVisitPicker = true }
                            .buttonStyle(PixelChipButtonStyle(isSelected: false))
                            .frame(minHeight: 44)
                        Button("Bring \(visit.sheepDisplayName) home") { store.bringVisitHome() }
                            .buttonStyle(PixelChipButtonStyle(isSelected: false))
                            .frame(minHeight: 44)
                    }
                } else {
                    Text("Send one of your sheep for \(SharedFarmVisit.stayNights) nights. Friends see its name and look; wool, rarity history and your Farm stay private.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Choose a sheep") { showsVisitPicker = true }
                        .buttonStyle(PixelPrimaryButtonStyle())
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
        }
    }
}

/// Picks one active sheep from the person's own Farm to send on a visit.
struct SharedFarmVisitPickerView: View {
    @ObservedObject var store: SharedFarmPrototypeStore
    @EnvironmentObject private var appViewModel: FocusRunViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selected: FlockSheep?

    private var sheep: [FlockSheep] { appViewModel.farmState.activeSheep }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("Friends will see the sheep’s name and look on the shared Farm for \(SharedFarmVisit.stayNights) nights. Nothing else from your Farm is shared, and the sheep stays yours.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    if sheep.isEmpty {
                        SlumberPartyV4UnavailableCard(title: "No sheep to send yet",
                            detail: "A completed Wind Down can help Ollie find a missing sheep.")
                    }
                    ForEach(sheep) { candidate in
                        Button { selected = candidate } label: {
                            HStack(spacing: AppSpacing.sm) {
                                FarmSheepSprite(sheep: candidate, protectedNightCount: appViewModel.coordinator.progress.farmCompletedRuns,
                                                size: 48, showsStatusBadge: false)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(candidate.displayName).font(AppTypography.body.weight(.semibold)).foregroundStyle(AppColors.ink)
                                    Text(candidate.rarity.title).font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                                }
                                Spacer(minLength: AppSpacing.xs)
                                if selected?.id == candidate.id {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(AppColors.grass).accessibilityHidden(true)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                        }
                        .buttonStyle(PixelChipButtonStyle(isSelected: selected?.id == candidate.id))
                        .accessibilityValue(selected?.id == candidate.id ? "Selected" : "")
                    }
                    if let selected {
                        Text(SharedFarmSocialCopy.visitSenderPreview(sheepName: selected.displayName))
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Send \(selected.displayName) to visit") {
                            store.sendVisit(sheepDefinitionID: selected.definitionID, sheepDisplayName: selected.displayName)
                            dismiss()
                        }
                        .buttonStyle(PixelPrimaryButtonStyle())
                        .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    if store.myVisit != nil {
                        Button("Bring my sheep home instead") {
                            store.bringVisitHome()
                            dismiss()
                        }
                        .buttonStyle(PixelChipButtonStyle(isSelected: false))
                        .frame(minHeight: 44)
                    }
                }
                .padding(AppSpacing.md)
                .padding(.bottom, AppSpacing.xxl)
            }
            .background(AppColors.paper.ignoresSafeArea())
            .navigationTitle("Send a sheep to visit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

#Preview("Friend card · greeting flow") {
    let fixture = SharedFarmPrototypeFixtures.viewModels()
    return SlumberPartyFriendCardView(viewModel: fixture.social, store: fixture.store, partyID: SharedFarmPrototypeFixtures.partyID,
                                      memberID: SharedFarmPrototypeFixtures.moss, showsSocialAvatar: true)
        .environmentObject(fixture.app)
}

#Preview("My card · received greetings") {
    let fixture = SharedFarmPrototypeFixtures.viewModels()
    return SlumberPartyFriendCardView(viewModel: fixture.social, store: fixture.store, partyID: SharedFarmPrototypeFixtures.partyID,
                                      memberID: SharedFarmPrototypeFixtures.me, showsSocialAvatar: true)
        .environmentObject(fixture.app)
}
