#if DEBUG
import SwiftUI

/// Members destination: the accessible list equivalent of the strip, plus
/// invitations and group settings. Replaces the People toggle.
struct StudyMembersSheet: View {
    let group: StudyGroup
    var send: (SocialStudyAction) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        StudyEyebrow(text: "PEOPLE")
                        ForEach(group.members) { member in
                            HStack(spacing: AppSpacing.sm) {
                                SlumberPartySocialAvatarView(presentation: member.presentation, avatarID: "shepherd", size: 44)
                                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                    Text(member.isMe ? "You" : member.name).font(AppTypography.headline)
                                    Text(member.isMe ? "Host · sharing \(group.partySharingOn ? "on" : "off")" : "Member").font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                                }
                                Spacer()
                                if !member.isMe {
                                    Menu {
                                        Button("Block", role: .destructive) { send(.block(member.id)) }
                                        Button("Report") { send(.report(member.id)) }
                                    } label: { Image(systemName: "ellipsis.circle").frame(width: 44, height: 44) }
                                    .accessibilityLabel("More for \(member.name)")
                                }
                            }
                            .frame(minHeight: 56)
                        }
                    }
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        StudyEyebrow(text: "INVITATIONS")
                        Text("Anyone here can share the current invite. New members accept the party agreement before anything is shared with them.")
                            .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText).fixedSize(horizontal: false, vertical: true)
                        StudySecondaryButton(title: "Share invite", symbol: "square.and.arrow.up") { send(.openMembers) }
                    }
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        StudyEyebrow(text: "SHARING AND NOTIFICATIONS")
                        settingRow("Party sharing", value: group.partySharingOn ? "On" : "Off", hint: "What this party can see. Leaving the party withdraws it.")
                        settingRow("Campfire sessions", value: "Separate agreement", hint: "Live Wind Down and Phone Away sessions need their own consent.")
                        settingRow("Start notifications", value: "Off", hint: "Generic lock-screen text, quiet 23:00–07:00.")
                    }
                    StudyTruthLine(text: "These rows point at existing group controls; the prototype records the intent only.")
                }
                .padding(AppSpacing.md)
            }
            .background(AppColors.paper.ignoresSafeArea())
            .navigationTitle("Members").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func settingRow(_ title: String, value: String, hint: String) -> some View {
        Button { send(.reviewAudience) } label: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(title).font(AppTypography.body.weight(.semibold)).foregroundStyle(AppColors.ink)
                    Text(hint).font(AppTypography.caption).foregroundStyle(AppColors.secondaryText).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Text(value).font(AppTypography.caption.weight(.semibold)).foregroundStyle(AppColors.grass)
            }
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
    }
}

/// Send-a-sheep lives with the meadow and shows the sheep itself, where it
/// is, and how it comes home.
struct StudySendSheepSheet: View {
    let group: StudyGroup
    let flock: [StudyFlockSheep]
    var send: (SocialStudyAction) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var busyID: UUID?

    private var mine: StudyVisitingSheep? { group.visitingSheep.first { $0.ownerID == group.myID } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    if let mine {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            StudyEyebrow(text: "VISITING NOW")
                            StudySheepRow(definitionID: mine.definitionID, name: mine.name,
                                          detail: "Beside your Shepherd in \(group.name). Name and look are visible to this party.",
                                          actionTitle: "Bring home", isBusy: busyID == mine.id) { busyID = mine.id; send(.recallSheep(mine.id)) }
                        }
                    }
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        StudyEyebrow(text: "YOUR FLOCK")
                        Text(mine == nil ? "Choose one to stand beside your Shepherd." : "One sheep per party. Bring \(mine?.name ?? "it") home first to send another.")
                            .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText).fixedSize(horizontal: false, vertical: true)
                        ForEach(flock) { sheep in
                            StudySheepRow(definitionID: sheep.definitionID, name: sheep.name,
                                          detail: sheep.visitingPartyName.map { "Visiting \($0)" } ?? "At home in your Barn",
                                          actionTitle: sheep.visitingPartyName == nil && mine == nil ? "Send to visit" : nil,
                                          isBusy: busyID == sheep.id) { busyID = sheep.id; send(.sendSheep(sheep.id)) }
                        }
                    }
                    StudyTruthLine(text: "Your flock keeps its progress. A visiting sheep is saved to your account and returns whenever you bring it home.")
                }
                .padding(AppSpacing.md)
            }
            .background(AppColors.paper.ignoresSafeArea())
            .navigationTitle("Sheep in the meadow").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

/// Proposed: after a private round or a returned session, choose one small
/// adjustment for my own next plan. Facts stay factual; reflection is optional.
struct StudyNextRoundSheet: View {
    let group: StudyGroup
    var send: (SocialStudyAction) -> Void
    @Environment(\.dismiss) private var dismiss
    private let choices = ["Start Wind Down 15 minutes earlier", "Keep tonight the same", "Swap reading for a shorter page count", "Ask Papa to check in tomorrow"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        StudyEyebrow(text: "THIS ROUND SO FAR")
                        Text("Night \(group.roundNight ?? 0) of 7").font(AppTypography.headline)
                        Text("2 completed Wind Downs recorded · 1 Phone Away · 45 before-bed min recorded").font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        StudyEyebrow(text: "ONE SMALL ADJUSTMENT")
                        ForEach(choices, id: \.self) { choice in
                            Button { send(.adjustNextRound(choice)); dismiss() } label: {
                                Text(choice).font(AppTypography.body).frame(maxWidth: .infinity, minHeight: 48, alignment: .leading).padding(.horizontal, AppSpacing.sm)
                            }
                            .buttonStyle(PixelChipButtonStyle(isSelected: false))
                        }
                    }
                    StudyTruthLine(text: "Changes only your own plan. Nobody else’s plan or permissions move. Skipping this is fine.")
                }
                .padding(AppSpacing.md)
            }
            .background(AppColors.paper.ignoresSafeArea())
            .navigationTitle("Next night").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Skip") { dismiss() } } }
        }
    }
}

// MARK: - Home entry-card sketches

/// Home card whose labels agree with the group home: identity, one live
/// line, one tap. No Campfire heading on a private group.
struct SlumberPartyHomeEntryCardStudy: View {
    let scenario: SocialStudyScenario
    var onOpen: () -> Void

    private var live: [(StudyPerson, StudySession)] {
        guard scenario.groupState.permitsLivePresence else { return [] }
        return scenario.group.sessions.filter { !$0.ended && $0.endsAt > scenario.now }.compactMap { s in scenario.group.person(s.personID).map { ($0, s) } }
    }

    private var statusLine: String {
        if let pending = scenario.pendingCheckIn { return "Back from \(pending.title) · share how it went" }
        if let first = live.first {
            let more = live.count > 1 ? " and \(live.count - 1) more" : ""
            return "Together now · \(first.0.name)\(more) · \(first.1.title) until \(first.1.endsAt.formatted(date: .omitted, time: .shortened))"
        }
        switch scenario.groupState {
        case .loading: return "Bringing the group into view…"
        case .failed: return "Group couldn’t be updated · your timer is unaffected"
        case .stale: return "Last seen 25 min ago · open to refresh"
        case .current: return scenario.group.roundNight.map { "Night \($0) of 7 · quiet by the fire" } ?? "Quiet by the fire · start when you’re ready"
        }
    }

    var body: some View {
        Button(action: onOpen) {
            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack {
                        StudyEyebrow(text: "SLUMBER PARTY")
                        Spacer()
                        StudyMemberStrip(people: scenario.group.members, maxShown: 3, size: 28, onOpen: onOpen).allowsHitTesting(false)
                    }
                    HStack {
                        Text(scenario.group.name).font(AppTypography.headline)
                        Spacer()
                        Image(systemName: "chevron.right").font(AppTypography.caption.weight(.bold)).accessibilityHidden(true)
                    }
                    Text(statusLine).font(AppTypography.caption).foregroundStyle(live.isEmpty ? AppColors.secondaryText : AppColors.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens your Slumber Party")
    }
}

/// A distinct Campfire entry that works for someone with no party.
struct CampfireHomeEntryCardStudy: View {
    let scenario: SocialStudyScenario
    var onOpen: () -> Void

    private var line: String {
        switch scenario.campfire.state {
        case .current: return "\(scenario.campfire.sharingNow) people sharing now · browse without sharing"
        case .loading: return "Checking who’s at the fire…"
        case .failed: return "Couldn’t reach the fire · nothing about you was sent"
        case .stale: return "Counts from 25 min ago · not current"
        }
    }

    var body: some View {
        Button(action: onOpen) {
            PixelCard {
                HStack(spacing: AppSpacing.sm) {
                    PaperCampfire().frame(width: 40, height: 40).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        StudyEyebrow(text: "CAMPFIRE")
                        Text("Company while your phone’s away").font(AppTypography.headline).fixedSize(horizontal: false, vertical: true)
                        Text(line).font(AppTypography.caption).foregroundStyle(AppColors.secondaryText).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(AppTypography.caption.weight(.bold)).accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the public Campfire. Browsing shares nothing.")
    }
}
#endif
