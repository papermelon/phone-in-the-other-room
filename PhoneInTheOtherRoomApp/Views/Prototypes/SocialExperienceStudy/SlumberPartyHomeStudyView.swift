#if DEBUG
import SwiftUI

/// Surface 1 — the private group home. Order answers the founder's four
/// questions in sequence: where am I (group identity), what is happening now
/// (Together now), what should I do (one primary action), what is ours
/// (meadow, improvement, recent record).
struct SlumberPartyHomeStudyView: View {
    let scenario: SocialStudyScenario
    var send: (SocialStudyAction) -> Void
    var onOpenPerson: (UUID) -> Void
    /// Capture aid only: start scrolled to the lower modules.
    var scrollsToBottom = false
    @State private var showsMembers = false
    @State private var showsSheep = false
    @State private var showsAdjustment = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var group: StudyGroup { scenario.group }
    private var now: Date { scenario.now }
    private var live: [(person: StudyPerson, session: StudySession)] {
        guard scenario.groupState.permitsLivePresence else { return [] }
        return group.sessions.filter { !$0.ended && $0.endsAt > now }.compactMap { session in
            group.person(session.personID).map { ($0, session) }
        }
    }
    private var finished: [(person: StudyPerson, session: StudySession)] {
        // My own pending check-in already leads the Tonight card.
        group.sessions.filter { ($0.ended || $0.endsAt <= now) && $0.id != scenario.pendingCheckIn?.id }
            .compactMap { session in group.person(session.personID).map { ($0, session) } }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                header
                StudyDataStateNotice(state: scenario.groupState, now: now, placeName: "the group") { send(.retry) }
                if scenario.groupState == .loading {
                    tonightCard.redacted(reason: .placeholder)
                } else {
                    tonightCard
                    if !live.isEmpty || !finished.isEmpty { togetherNow }
                    meadowCard
                    improvementCard
                    recentCard
                }
            }
            .padding(.horizontal, AppSpacing.md).padding(.vertical, AppSpacing.sm).padding(.bottom, AppSpacing.xxl)
        }
        .defaultScrollAnchor(scrollsToBottom ? .bottom : .top)
        .background(AppColors.paper.ignoresSafeArea())
        // The display header owns identity; an inline title would repeat it.
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showsMembers) { StudyMembersSheet(group: group, send: send) }
        .sheet(isPresented: $showsSheep) { StudySendSheepSheet(group: group, flock: scenario.myFlock, send: send) }
        .sheet(isPresented: $showsAdjustment) { StudyNextRoundSheet(group: group, send: send) }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            StudyEyebrow(text: "SLUMBER PARTY")
            HStack(alignment: .top) {
                Text(group.name).font(AppTypography.display(28)).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: AppSpacing.sm)
                if !dynamicTypeSize.isAccessibilitySize { memberStrip }
            }
            if dynamicTypeSize.isAccessibilitySize { memberStrip }
            Text(roundLine).font(AppTypography.caption).foregroundStyle(AppColors.secondaryText).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var memberStrip: some View {
        StudyMemberStrip(people: group.members) { showsMembers = true; send(.openMembers) }
    }

    private var roundLine: String {
        let people = "\(group.members.count) people"
        let sharing = group.partySharingOn ? "sharing on" : "your sharing is off"
        if let night = group.roundNight { return "Night \(night) of 7 · \(people) · \(sharing)" }
        return "No round running · \(people) · \(sharing)"
    }

    // MARK: Tonight — one primary action

    @ViewBuilder private var tonightCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                if let pending = scenario.pendingCheckIn {
                    checkIn(pending)
                } else if let own = scenario.ownSession {
                    StudyEyebrow(text: "YOU’RE AT THE FIRE")
                    Text("\(own.title) until \(own.endsAt.formatted(date: .omitted, time: .shortened))").font(AppTypography.headline)
                    StudyPrimaryButton(title: "Back to your session", symbol: "moon.stars") { send(.backToRunningSession) }
                } else {
                    StudyEyebrow(text: "TONIGHT")
                    Text(tonightTitle).font(AppTypography.headline).fixedSize(horizontal: false, vertical: true)
                    StudyPrimaryButton(title: live.isEmpty ? "Start Wind Down" : "Join with my own Wind Down", symbol: "moon.zzz") {
                        send(.startSession(.windDown, group.partySharingOn ? .myParties : .justMe))
                    }
                    StudySecondaryButton(title: "Phone Away instead", symbol: "iphone.slash") { send(.startSession(.phoneAway, group.partySharingOn ? .myParties : .justMe)) }
                    StudyTruthLine(text: group.partySharingOn
                        ? "Shares with \(group.name) when you start. You can change that on the start sheet."
                        : "Your sharing is off. Starting stays private unless you turn it on at the start sheet.")
                    Button("Suggest a shared plan for tonight") { send(.suggestEveningPlan) }
                        .font(AppTypography.caption.weight(.semibold)).tint(AppColors.grass).frame(minHeight: 44)
                        .accessibilityHint("Proposed: each adult accepts or edits their own part")
                }
            }
        }
    }

    private var tonightTitle: String {
        if !live.isEmpty {
            let names = live.map(\.person.name)
            switch names.count {
            case 1: return "\(names[0]) is at the fire."
            case 2: return "\(names[0]) and \(names[1]) are at the fire."
            default: return "\(names[0]), \(names[1]) and \(names.count - 2) more are at the fire."
            }
        }
        if case .stale = scenario.groupState { return "Ollie saved a spot by the fire. Nobody is shown as here until the group refreshes." }
        return "Ollie saved a spot by the fire. The fire lights when someone starts."
    }

    @ViewBuilder private func checkIn(_ session: StudySession) -> some View {
        StudyEyebrow(text: "BACK FROM \(session.title.uppercased())")
        Text(session.checkInRequested ? "Papa asked how it went." : "How did your plan go?").font(AppTypography.headline)
        if let intention = session.intention { Text("“\(intention)”").font(AppTypography.body) }
        StudyStackOrRow {
            ForEach(CampfireOutcome.allCases) { outcome in
                StudySecondaryButton(title: outcome.title) { send(.shareCheckIn(session.id, outcome)) }
            }
        }
        StudyTruthLine(text: "Optional. Shared only with \(group.name). A finished timer doesn’t mark the task done.")
        if group.roundNight != nil {
            Button("Choose a small adjustment for tonight") { showsAdjustment = true }
                .font(AppTypography.caption.weight(.semibold)).tint(AppColors.grass).frame(minHeight: 44)
        }
    }

    // MARK: Together now

    private var togetherNow: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                StudyEyebrow(text: "TOGETHER NOW")
                Spacer()
                Text(live.isEmpty ? "Quiet" : "\(live.count) sharing").font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
            }
            if !live.isEmpty {
                StudyFireScene(seated: live, height: live.count > 4 ? 200 : 150) { id in onOpenPerson(id); send(.openPerson(id)) }
            }
            VStack(spacing: 0) {
                ForEach(live, id: \.session.id) { entry in
                    StudySessionRow(person: entry.person, session: entry.session, now: now) { onOpenPerson(entry.person.id); send(.openPerson(entry.person.id)) }
                }
                ForEach(finished, id: \.session.id) { entry in
                    finishedRow(entry)
                }
            }
            StudyTruthLine(text: "App-reported sessions from members. They don’t show sleep or where a phone is.")
        }
    }

    private func finishedRow(_ entry: (person: StudyPerson, session: StudySession)) -> some View {
        HStack(spacing: AppSpacing.sm) {
            SlumberPartySocialAvatarView(presentation: entry.person.presentation, avatarID: "shepherd", size: 40)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(entry.person.isMe ? "You" : entry.person.name).font(AppTypography.headline)
                Text(entry.session.outcome.map { "\(entry.session.title) finished · \($0.title)" } ?? "\(entry.session.title) finished · no check-in yet")
                    .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText).fixedSize(horizontal: false, vertical: true)
                if let note = entry.session.reflection { Text("“\(note)”").font(AppTypography.caption) }
            }
            Spacer(minLength: AppSpacing.xs)
            if !entry.person.isMe, entry.session.outcome != nil {
                Button("Moon glow") { send(.acknowledgeResult(entry.session.id)) }
                    .buttonStyle(PixelChipButtonStyle(isSelected: false)).frame(maxWidth: 120, minHeight: 44)
                    .accessibilityHint("Sends a fixed cheer for their shared result")
            }
        }
        .frame(minHeight: 56)
    }

    // MARK: Shared meadow

    private var meadowCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                StudyEyebrow(text: "SHARED MEADOW")
                Button { send(.openMeadow) } label: { meadowBanner }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open the shared meadow. \(group.members.count) Shepherds, \(group.visitingSheep.count) visiting sheep.")
                Text(meadowLine).font(AppTypography.caption).foregroundStyle(AppColors.secondaryText).fixedSize(horizontal: false, vertical: true)
                StudyStackOrRow {
                    StudySecondaryButton(title: "Open meadow", symbol: "leaf") { send(.openMeadow) }
                    StudySecondaryButton(title: mySheepVisiting == nil ? "Send a sheep" : "Your sheep", symbol: "pawprint") { showsSheep = true }
                }
            }
        }
    }

    private var mySheepVisiting: StudyVisitingSheep? { group.visitingSheep.first { $0.ownerID == group.myID } }

    private var meadowLine: String {
        var parts = ["\(group.members.count) Shepherds"]
        if let mine = mySheepVisiting { parts.append("\(mine.name) is visiting for you") }
        let others = group.visitingSheep.filter { $0.ownerID != group.myID }
        if let first = others.first { parts.append("\(first.name) with \(group.person(first.ownerID)?.name ?? "a member")") }
        return parts.joined(separator: " · ") + ". Saved places, not activity."
    }

    /// A short static glimpse of the real meadow so the entry keeps the art
    /// without making a large landscape the landing experience.
    private var meadowBanner: some View {
        GeometryReader { proxy in
            ZStack {
                Image(AssetSlot.Farm.sharedMeadowDusk).resizable().interpolation(.high).aspectRatio(contentMode: .fill)
                    .frame(width: proxy.size.width, height: proxy.size.height).clipped()
                ForEach(Array(group.members.prefix(4).enumerated()), id: \.element.id) { index, member in
                    SlumberPartySocialAvatarView(presentation: member.presentation, avatarID: "shepherd", size: 46, showsBackdrop: false)
                        .position(x: proxy.size.width * (0.18 + 0.21 * Double(index)), y: proxy.size.height * 0.66)
                }
                ForEach(Array(group.visitingSheep.prefix(3).enumerated()), id: \.element.id) { index, sheep in
                    PixelAssetImage(name: SheepCatalog.definition(for: sheep.definitionID)?.assetName ?? AssetSlot.Sheep.common)
                        .frame(width: 30, height: 30)
                        .position(x: proxy.size.width * (0.30 + 0.24 * Double(index)), y: proxy.size.height * 0.86)
                }
                if group.lanternContributions >= group.lanternRequired {
                    PaperPastureLantern(isLit: true).frame(width: 28, height: 40).position(x: proxy.size.width * 0.9, y: proxy.size.height * 0.6)
                }
            }
        }
        .frame(height: 110).clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(AppColors.stroke.opacity(0.35), lineWidth: 1))
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "arrow.up.left.and.arrow.down.right").font(AppTypography.caption.weight(.bold)).foregroundStyle(AppColors.ink)
                .padding(6).background(AppColors.paper.opacity(0.9), in: Circle()).padding(AppSpacing.xs)
        }
        .accessibilityHidden(true)
    }

    // MARK: Our next improvement

    private var improvementCard: some View {
        let done = min(group.lanternContributions, group.lanternRequired)
        return Button { send(.openImprovement) } label: {
            PixelCard {
                HStack(alignment: .center, spacing: AppSpacing.md) {
                    PaperPastureLantern(isLit: done >= group.lanternRequired).frame(width: 44, height: 64).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        StudyEyebrow(text: "OUR NEXT IMPROVEMENT")
                        Text(done >= group.lanternRequired ? "The lantern is lit" : "A lantern for our meadow").font(AppTypography.headline)
                        ProgressView(value: Double(done), total: Double(group.lanternRequired)).tint(AppColors.grass)
                        Text("\(done) of \(group.lanternRequired) · one per member per party-day from a completed round grant")
                            .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText).fixedSize(horizontal: false, vertical: true)
                    }
                    Image(systemName: "chevron.right").font(AppTypography.caption.weight(.bold)).foregroundStyle(AppColors.grass).accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Our next improvement: lantern, \(done) of \(group.lanternRequired) contributions")
        .accessibilityHint("Opens the group project details")
    }

    // MARK: Recent record

    private var recentCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            StudyEyebrow(text: "RECENT")
            if group.recentRecords.isEmpty {
                Text("No shared record yet. That says nothing about who took part.").font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
            }
            ForEach(group.recentRecords) { record in
                HStack(spacing: AppSpacing.sm) {
                    if let person = group.person(record.personID) {
                        SlumberPartySocialAvatarView(presentation: person.presentation, avatarID: "shepherd", size: 36)
                    }
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text("\(group.person(record.personID)?.name ?? "A member") · \(record.kind.title) finished").font(AppTypography.body.weight(.semibold))
                        Text(recordDetail(record)).font(AppTypography.caption).foregroundStyle(AppColors.secondaryText).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .frame(minHeight: 48)
                .accessibilityElement(children: .combine)
            }
            StudyTruthLine(text: "Self-reported from each member’s iPhone to this party. Not independently verified.")
        }
    }

    private func recordDetail(_ record: StudyRecord) -> String {
        let when = record.occurredAt.formatted(.dateTime.weekday(.wide).hour().minute())
        guard let minutes = record.roundedMinutes else { return "\(when) · before-bed minutes weren’t shared" }
        return "\(when) · \(minutes) before-bed min recorded, rounded"
    }
}
#endif
