#if DEBUG
import SwiftUI

/// Surface 3 — one person, one session, the few things I can do about it.
/// The same card serves a party member and a public participant; the badge,
/// timing precision and available actions change with the audience.
struct SocialPersonCardStudyView: View {
    let scenario: SocialStudyScenario
    let personID: UUID
    var send: (SocialStudyAction) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var encouraged = false
    @State private var offeredCheckIn = false
    @State private var connectionSent = false

    private var person: StudyPerson? {
        scenario.group.person(personID) ?? scenario.campfire.participants.first { $0.id == personID }
    }
    private var session: StudySession? {
        (scenario.group.sessions + scenario.campfire.sessions).first { $0.personID == personID }
    }
    private var now: Date { scenario.now }
    private var isActive: Bool { session.map { !$0.ended && $0.endsAt > now } ?? false }
    private var isPublic: Bool { person?.audience.isPublic ?? false }
    private var canJoin: Bool { scenario.ownSession == nil && isActive && !(person?.isMe ?? false) }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let person {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        identity(person)
                        if let session { sessionCard(session, person: person) } else { noSession(person) }
                        if let session, !person.isMe { actions(session, person: person) }
                        if let session, person.isMe, session.ended, session.outcome == nil { myCheckIn(session) }
                        if isPublic { connectionSection(person) }
                        StudyTruthLine(text: isPublic
                            ? "Public card: a chosen name, Shepherd, session kind, one preset activity and a rough time left. No exact times, parties or history."
                            : "Party card: app-reported by \(person.name)’s iPhone to \(scenario.group.name). It doesn’t show sleep or where the phone is.")
                    }
                    .padding(AppSpacing.md).padding(.bottom, AppSpacing.xxl)
                } else {
                    Text("This person isn’t available right now.").font(AppTypography.body).padding()
                }
            }
            .background(AppColors.paper.ignoresSafeArea())
            .navigationTitle(isPublic ? "At the fire" : "In \(scenario.group.name)").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                if let person, !person.isMe {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            Button("Block \(person.name)", role: .destructive) { send(.block(person.id)) }
                            Button("Report") { send(.report(person.id)) }
                        } label: { Image(systemName: "ellipsis.circle") }
                        .accessibilityLabel("Block or report")
                    }
                }
            }
        }
    }

    // MARK: Identity

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private func identity(_ person: StudyPerson) -> some View {
        let avatar = SlumberPartySocialAvatarView(presentation: person.presentation, avatarID: "shepherd", size: 96)
        let text = VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(person.isMe ? "You" : person.name).font(AppTypography.display(26)).fixedSize(horizontal: false, vertical: true)
            Text(person.audience.badge).font(AppTypography.caption.weight(.semibold)).foregroundStyle(isPublic ? AppColors.lavender : AppColors.grass)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, AppSpacing.xs).padding(.vertical, AppSpacing.xxs)
                .background((isPublic ? AppColors.lavender : AppColors.grassLight).opacity(0.2), in: RoundedRectangle(cornerRadius: AppRadius.md))
            if isPublic, case .accepted = person.connection {
                Label("Connected", systemImage: "link").font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
            }
        }
        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppSpacing.sm) { avatar; text }
            } else {
                HStack(spacing: AppSpacing.md) { avatar; text }
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Session

    private func sessionCard(_ session: StudySession, person: StudyPerson) -> some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Label(session.title, systemImage: isActive ? "flame" : "leaf").font(AppTypography.headline)
                Text(timing(session)).font(AppTypography.body).foregroundStyle(AppColors.secondaryText)
                if let intention = session.intention, !intention.isEmpty, !isPublic {
                    Text("“\(intention)”").font(AppTypography.body).fixedSize(horizontal: false, vertical: true)
                }
                if !isPublic {
                    if let buddy = session.buddyPersonID, let name = scenario.group.person(buddy)?.name {
                        Label("\(buddy == scenario.group.myID ? "You" : name) will check in afterwards", systemImage: "person.badge.clock").font(AppTypography.caption)
                    } else if session.asksForBuddy, isActive {
                        Label("A check-in buddy is welcome", systemImage: "person.badge.plus").font(AppTypography.caption)
                    }
                }
                if session.encouragementCount > 0 || encouraged {
                    Text("Encouragement from \(session.encouragementCount + (encouraged ? 1 : 0)) \(session.encouragementCount + (encouraged ? 1 : 0) == 1 ? "person" : "people")")
                        .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                }
                if let outcome = session.outcome {
                    Divider()
                    Text("Shared check-in: \(outcome.title)").font(AppTypography.body.weight(.semibold))
                    if let note = session.reflection { Text("“\(note)”").font(AppTypography.body).fixedSize(horizontal: false, vertical: true) }
                    Text("Self-reported. A finished timer doesn’t mark the task done.").font(AppTypography.caption).foregroundStyle(AppColors.muted)
                } else if session.ended, !isPublic {
                    Text(session.kind == .windDown ? "Check-in waits until morning quiet ends" : "No check-in shared yet").font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                }
            }
        }
    }

    private func timing(_ session: StudySession) -> String {
        if session.ended || session.endsAt <= now { return "Finished" }
        if isPublic { let band = session.remainingBand(at: now); return band.prefix(1).uppercased() + band.dropFirst() }
        return "Planned until \(session.endsAt.formatted(date: .omitted, time: .shortened))"
    }

    private func noSession(_ person: StudyPerson) -> some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("No session right now").font(AppTypography.headline)
                Text("\(person.name)’s Shepherd is in the shared meadow. A saved place isn’t activity.").font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Actions for someone else's session

    @ViewBuilder private func actions(_ session: StudySession, person: StudyPerson) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            StudyEyebrow(text: isActive ? "WHILE THEY’RE AT THE FIRE" : "AFTERWARDS")
            if canJoin {
                StudyPrimaryButton(title: "Join with my own \(session.kind.title)", symbol: session.kind == .windDown ? "moon.zzz" : "iphone.slash") {
                    send(.joinWithOwnSession(session.id, session.kind))
                }
                StudyTruthLine(text: "Your own timer, your own intention. Joining shares your session the way you choose next.")
            } else if isActive, scenario.ownSession != nil {
                StudySecondaryButton(title: "Back to your session", symbol: "moon.stars") { send(.backToRunningSession) }
            }
            StudyStackOrRow {
                if isActive {
                    StudySecondaryButton(title: encouraged || session.encouragedByMe ? "Encouragement sent" : "Send encouragement", symbol: "hands.clap",
                                         isSelected: encouraged || session.encouragedByMe) {
                        guard !encouraged, !session.encouragedByMe else { return }
                        encouraged = true; send(.encourage(session.id))
                    }
                }
                if !isPublic, isActive, session.asksForBuddy, session.buddyPersonID == nil {
                    StudySecondaryButton(title: offeredCheckIn ? "You’ll check in" : "I’ll check in afterwards", symbol: "person.badge.clock", isSelected: offeredCheckIn) {
                        offeredCheckIn = true; send(.offerCheckIn(session.id))
                    }
                }
                if !isPublic, !isActive, session.buddyPersonID == scenario.group.myID, session.outcome == nil, !session.checkInRequested {
                    StudySecondaryButton(title: "Ask how it went", symbol: "bubble.left") { send(.askHowItWent(session.id)) }
                }
                if !isActive, session.outcome != nil {
                    StudySecondaryButton(title: "Moon glow", symbol: "moon.stars") { send(.acknowledgeResult(session.id)) }
                }
            }
            if isPublic, isActive {
                StudyTruthLine(text: "Encouragement is a fixed message. Public sessions don’t offer check-in buddies.")
            }
        }
    }

    // MARK: My own return

    @ViewBuilder private func myCheckIn(_ session: StudySession) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            StudyEyebrow(text: "HOW DID IT GO?")
            StudyStackOrRow {
                ForEach(CampfireOutcome.allCases) { outcome in
                    StudySecondaryButton(title: outcome.title) { send(.shareCheckIn(session.id, outcome)) }
                }
            }
            StudyTruthLine(text: "Optional and shared only with \(scenario.group.name).")
        }
    }

    // MARK: Proposed public connection

    @ViewBuilder private func connectionSection(_ person: StudyPerson) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            StudyEyebrow(text: "CONNECTION · PROPOSED")
            switch person.connection {
            case .accepted:
                Text("You and \(person.name) connected after a shared session.").font(AppTypography.body)
                StudySecondaryButton(title: "Invite to a Slumber Party", symbol: "envelope") { send(.inviteToParty(person.id)) }
                StudyTruthLine(text: "An invitation uses the party’s own agreement. Connection alone shows no history, schedule or Farm.")
            case .requestedByThem:
                Text("\(person.name) asked to connect.").font(AppTypography.body)
                StudyStackOrRow {
                    StudySecondaryButton(title: "Accept", symbol: "checkmark") { send(.respondToConnection(person.id, accept: true)) }
                    StudySecondaryButton(title: "Decline") { send(.respondToConnection(person.id, accept: false)) }
                }
            case .requestedByMe:
                Text("Requested. \(person.name) will see it when they return.").font(AppTypography.body)
            case .none:
                if connectionSent {
                    Text("Requested. \(person.name) will see it when they return.").font(AppTypography.body)
                } else {
                    StudySecondaryButton(title: "Request to connect", symbol: "link") { connectionSent = true; send(.requestConnection(person.id)) }
                    StudyTruthLine(text: "Mutual only. One open request per person; it expires in seven days. No chat comes with it.")
                }
            }
        }
    }
}
#endif
