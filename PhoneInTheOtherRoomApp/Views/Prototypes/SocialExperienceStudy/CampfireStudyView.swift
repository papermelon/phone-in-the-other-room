#if DEBUG
import SwiftUI

/// Surface 2 — the standalone public Campfire. Discovery first, then one
/// bounded fire, then a start that always passes through an audience choice.
/// Works with zero Slumber Parties. All people here are synthetic.
struct CampfireStudyView: View {
    let scenario: SocialStudyScenario
    var send: (SocialStudyAction) -> Void
    var onOpenPerson: (UUID) -> Void
    var scrollsToBottom = false
    @State private var selectedGathering: String
    @State private var startKind: StudySessionKind?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(scenario: SocialStudyScenario, send: @escaping (SocialStudyAction) -> Void, onOpenPerson: @escaping (UUID) -> Void, scrollsToBottom: Bool = false) {
        self.scenario = scenario
        self.send = send
        self.onOpenPerson = onOpenPerson
        self.scrollsToBottom = scrollsToBottom
        _selectedGathering = State(initialValue: scenario.campfire.selectedGathering)
    }

    private var campfire: StudyCampfire { scenario.campfire }
    private var now: Date { scenario.now }
    private var seated: [(person: StudyPerson, session: StudySession)] {
        guard campfire.state.permitsLivePresence else { return [] }
        return campfire.sessions.compactMap { session in campfire.participants.first { $0.id == session.personID }.map { ($0, session) } }
    }
    private var gatheringCount: Int { campfire.gatherings.first { $0.title == selectedGathering }?.count ?? seated.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                header
                audienceBanner
                StudyDataStateNotice(state: campfire.state, now: now, placeName: "Campfire") { send(.retry) }
                if campfire.state == .loading {
                    fireSection.redacted(reason: .placeholder)
                } else {
                    gatherings
                    fireSection
                }
                startSection
                StudyTruthLine(text: "App-reported sessions from people who chose Public. Not sleep, attention or where a phone is. Blocked people are left out of what you see.")
            }
            .padding(.horizontal, AppSpacing.md).padding(.vertical, AppSpacing.sm).padding(.bottom, AppSpacing.xxl)
        }
        .defaultScrollAnchor(scrollsToBottom ? .bottom : .top)
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .sheet(item: $startKind) { kind in
            StudyAudienceReviewSheet(kind: kind, campfire: campfire, me: scenario.group.me, hasParties: true, send: send)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            StudyEyebrow(text: "CAMPFIRE")
            Text("Company while your phone’s away").font(AppTypography.display(26)).fixedSize(horizontal: false, vertical: true)
            Text(countLine).font(AppTypography.caption).foregroundStyle(AppColors.secondaryText).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var countLine: String {
        switch campfire.state {
        case let .current(observedAt):
            let age = max(0, Int(now.timeIntervalSince(observedAt) / 60))
            return "\(campfire.sharingNow) sharing now · \(campfire.totalWindDown) Wind Down · \(campfire.totalPhoneAway) Phone Away · updated \(age == 0 ? "just now" : "\(age) min ago")"
        case .loading: return "Checking who’s at the fire…"
        case .failed: return "Counts unavailable"
        case .stale: return "Counts aren’t current"
        }
    }

    // MARK: Audience

    private var audienceBanner: some View {
        let title = Text(campfire.publicAgreementAccepted ? "You’re browsing as \(campfire.myPublicName)." : "Public sharing is off.").font(AppTypography.headline)
        let detail = Text(campfire.publicAgreementAccepted
                          ? "Nothing is shared until you start a session and choose Public. Saved choice: \(campfire.savedAudience.title)."
                          : "Browsing here shares nothing about you. You can turn it on when you start a session.")
            .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
        let review = Button("Review audience") { send(.reviewAudience); startKind = .windDown }
            .font(AppTypography.caption.weight(.semibold)).tint(AppColors.grass).frame(minHeight: 44)
        let icon = Image(systemName: campfire.publicAgreementAccepted ? "eye" : "eye.slash").font(AppTypography.headline).foregroundStyle(AppColors.grass)
        return PixelCard {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    icon.accessibilityHidden(true)
                    title.fixedSize(horizontal: false, vertical: true)
                    detail.fixedSize(horizontal: false, vertical: true)
                    review
                }
            } else {
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    icon.accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        title.fixedSize(horizontal: false, vertical: true)
                        detail.fixedSize(horizontal: false, vertical: true)
                        review
                    }
                }
            }
        }
    }

    // MARK: Gatherings

    private var gatherings: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            StudyEyebrow(text: "GATHERINGS")
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppSpacing.xs) { gatheringChips }
            } else {
                ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: AppSpacing.xs) { gatheringChips.fixedSize(horizontal: true, vertical: false) } }
            }
        }
        .accessibilityElement(children: .contain).accessibilityLabel("Gatherings")
    }

    private var gatheringChips: some View {
        ForEach(campfire.gatherings) { gathering in
            Button { selectedGathering = gathering.title; send(.changeGathering(gathering.title)) } label: {
                HStack(spacing: AppSpacing.xxs) {
                    Text(gathering.title).font(AppTypography.body)
                    Text("\(gathering.count)").font(AppTypography.caption.weight(.semibold)).opacity(0.8)
                }
                .padding(.horizontal, AppSpacing.sm)
            }
            .buttonStyle(PixelChipButtonStyle(isSelected: gathering.title == selectedGathering)).frame(minHeight: 44)
            .accessibilityLabel("\(gathering.title), \(gathering.count) sharing")
            .accessibilityAddTraits(gathering.title == selectedGathering ? .isSelected : [])
        }
    }

    // MARK: The fire

    @ViewBuilder private var fireSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                StudyEyebrow(text: selectedGathering.uppercased())
                Spacer()
                if !seated.isEmpty {
                    Text(gatheringCount > seated.count ? "\(seated.count) of \(gatheringCount) at this fire" : "\(seated.count) at this fire")
                        .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                }
            }
            if !seated.isEmpty {
                StudyFireScene(seated: seated, height: seated.count > 4 ? 210 : 170) { id in onOpenPerson(id); send(.openPerson(id)) }
                VStack(spacing: 0) {
                    ForEach(seated, id: \.session.id) { entry in
                        StudySessionRow(person: entry.person, session: entry.session, now: now) { onOpenPerson(entry.person.id); send(.openPerson(entry.person.id)) }
                    }
                }
                if gatheringCount > seated.count {
                    Button("More people at \(selectedGathering) (\(gatheringCount - seated.count))") { send(.changeGathering(selectedGathering)) }
                        .font(AppTypography.caption.weight(.semibold)).tint(AppColors.grass).frame(minHeight: 44)
                }
            } else {
                emptyFire
            }
        }
    }

    private var emptyFire: some View {
        PixelCard {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                PaperCampfire().frame(width: 52, height: 52).opacity(0.5).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(emptyTitle).font(AppTypography.headline).fixedSize(horizontal: false, vertical: true)
                    Text(emptyDetail).font(AppTypography.caption).foregroundStyle(AppColors.secondaryText).fixedSize(horizontal: false, vertical: true)
                    if let next = campfire.gatherings.first(where: { $0.count > 0 && $0.title != selectedGathering }) {
                        StudySecondaryButton(title: "Try \(next.title) (\(next.count))") { selectedGathering = next.title; send(.changeGathering(next.title)) }
                    }
                }
            }
        }
    }

    private var emptyTitle: String {
        switch campfire.state {
        case .current: return "No one at \(selectedGathering) right now."
        case .stale: return "\(selectedGathering) isn’t current."
        case .failed: return "The fire couldn’t be reached."
        case .loading: return "Checking…"
        }
    }

    private var emptyDetail: String {
        switch campfire.state {
        case .current: return "Sit down first and the fire lights for the next person. Or try another gathering."
        case .stale: return "Refresh before trusting who is here."
        case .failed: return "Your own timer and Farm are unaffected."
        case .loading: return ""
        }
    }

    // MARK: Start

    private var startSection: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                StudyEyebrow(text: "SIT DOWN")
                Text(scenario.ownSession == nil ? "Start your own session here" : "You already have a session running").font(AppTypography.headline)
                if scenario.ownSession == nil {
                    StudyPrimaryButton(title: "Start Wind Down", symbol: "moon.zzz") { startKind = .windDown }
                    StudySecondaryButton(title: "Start Phone Away", symbol: "iphone.slash") { startKind = .phoneAway }
                    StudyTruthLine(text: "You choose the audience next. Starting from here does not make it public.")
                } else {
                    StudyPrimaryButton(title: "Back to your session", symbol: "moon.stars") { send(.backToRunningSession) }
                }
            }
        }
    }
}

/// The explicit audience step before any start. Public options stay off
/// until the separate public agreement is accepted; the card preview shows
/// exactly what a stranger would see.
struct StudyAudienceReviewSheet: View {
    let kind: StudySessionKind
    let campfire: StudyCampfire
    let me: StudyPerson?
    let hasParties: Bool
    var send: (SocialStudyAction) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var choice: StudyAudienceChoice
    @State private var accepted: Bool
    @State private var activity: CampfireActivity = .reading
    @State private var publicName: String

    init(kind: StudySessionKind, campfire: StudyCampfire, me: StudyPerson?, hasParties: Bool, send: @escaping (SocialStudyAction) -> Void) {
        self.kind = kind; self.campfire = campfire; self.me = me; self.hasParties = hasParties; self.send = send
        _choice = State(initialValue: campfire.savedAudience)
        _accepted = State(initialValue: campfire.publicAgreementAccepted)
        _publicName = State(initialValue: campfire.myPublicName.isEmpty ? "Fern" : campfire.myPublicName)
    }

    private var choices: [StudyAudienceChoice] { hasParties ? StudyAudienceChoice.allCases : [.justMe, .publicCampfire] }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        StudyEyebrow(text: "WHO SEES THIS \(kind.title.uppercased())?")
                        ForEach(choices) { option in
                            let locked = option.includesPublic && !accepted
                            Button { if !locked { choice = option } } label: {
                                HStack(alignment: .top, spacing: AppSpacing.sm) {
                                    Image(systemName: choice == option ? "largecircle.fill.circle" : "circle").foregroundStyle(AppColors.grass).accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                        Text(option.title).font(AppTypography.body.weight(.semibold)).foregroundStyle(AppColors.ink)
                                        Text(locked ? "Accept the public sharing agreement below first." : option.detail)
                                            .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText).fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                            }
                            .buttonStyle(.plain).opacity(locked ? 0.6 : 1)
                            .accessibilityAddTraits(choice == option ? .isSelected : [])
                        }
                    }
                    if !accepted {
                        PixelCard {
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text("Public sharing agreement").font(AppTypography.headline)
                                Text("Public shows a name you choose, your Shepherd, the session kind, one preset activity and a rough time left. Never your party names, exact times, tasks, Health or Farm. Ends when the session ends or you withdraw.")
                                    .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText).fixedSize(horizontal: false, vertical: true)
                                StudySecondaryButton(title: "Accept and allow Public") { accepted = true; choice = .publicCampfire; send(.acceptPublicAgreement) }
                            }
                        }
                    }
                    if choice.includesPublic { publicPreview }
                    StudyPrimaryButton(title: "Start \(kind.title)") { send(.startSession(kind, choice)); dismiss() }
                    StudyTruthLine(text: "One choice per session; it can’t be widened after starting. Ending early removes you from the fire when it syncs.")
                }
                .padding(AppSpacing.md)
            }
            .background(AppColors.paper.ignoresSafeArea())
            .navigationTitle("Audience").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }

    private var publicPreview: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            StudyEyebrow(text: "WHAT THE FIRE SEES")
            PixelCard {
                HStack(spacing: AppSpacing.sm) {
                    if let me { SlumberPartySocialAvatarView(presentation: me.presentation, avatarID: "shepherd", size: 56) }
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        TextField("Public name", text: $publicName).font(AppTypography.headline).textFieldStyle(.roundedBorder)
                        Text(kind == .windDown ? "Wind Down · through the night" : "\(activity.title) · about an hour left")
                            .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                    }
                }
            }
            if kind == .phoneAway {
                StudyStackOrRow {
                    ForEach([CampfireActivity.reading, .studying, .making, .resting]) { option in
                        StudySecondaryButton(title: option.title, isSelected: activity == option) { activity = option }
                    }
                }
            }
        }
    }
}
#endif
