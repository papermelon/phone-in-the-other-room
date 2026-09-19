#if DEBUG
import SwiftUI

// Small shared pieces for the three study surfaces. They use the production
// Shepherd renderer, sheep catalog art, paper meadow and campfire so the
// prototype reads as Counting Sheep rather than a generic dashboard.

/// Section label. Capped like production name capsules so the monospaced
/// eyebrow doesn't dominate at accessibility sizes; the content beneath scales.
struct StudyEyebrow: View {
    let text: String
    var body: some View {
        Text(text).font(pixelFont(.caption)).foregroundStyle(AppColors.grass)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

struct StudyTruthLine: View {
    let text: String
    var body: some View {
        Text(text).font(AppTypography.caption).foregroundStyle(AppColors.muted)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Horizontal when it fits, stacked otherwise. Buttons keep 44pt targets.
struct StudyStackOrRow<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppSpacing.xs) { content }
            VStack(alignment: .leading, spacing: AppSpacing.xs) { content }
        }
    }
}

struct StudyPrimaryButton: View {
    let title: String
    var symbol: String? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                if let symbol { Image(systemName: symbol).accessibilityHidden(true) }
                Text(title).fixedSize(horizontal: false, vertical: true)
            }
            .font(AppTypography.headline)
            .frame(maxWidth: .infinity, minHeight: 24)
        }
        .buttonStyle(PixelPrimaryButtonStyle())
    }
}

struct StudySecondaryButton: View {
    let title: String
    var symbol: String? = nil
    var isSelected = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                if let symbol { Image(systemName: symbol).accessibilityHidden(true) }
                Text(title).fixedSize(horizontal: false, vertical: true)
            }
            .font(AppTypography.body)
            .padding(.horizontal, AppSpacing.sm)
        }
        .buttonStyle(PixelChipButtonStyle(isSelected: isSelected))
        .frame(minHeight: 44)
    }
}

/// Compact membership without a scene: identity at a glance, one tap to the
/// Members destination, and a list equivalent for VoiceOver.
struct StudyMemberStrip: View {
    let people: [StudyPerson]
    var maxShown = 4
    var size: CGFloat = 34
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: AppSpacing.xs) {
                HStack(spacing: -size * 0.28) {
                    ForEach(people.prefix(maxShown)) { person in
                        SlumberPartySocialAvatarView(presentation: person.presentation, avatarID: person.sheepAvatarID ?? "shepherd", size: size)
                            .background(AppColors.paper, in: Circle())
                            .overlay(Circle().stroke(AppColors.paper, lineWidth: 2))
                    }
                }
                if people.count > maxShown {
                    Text("+\(people.count - maxShown)").font(AppTypography.caption.weight(.semibold)).foregroundStyle(AppColors.grass)
                }
                Image(systemName: "chevron.right").font(AppTypography.caption.weight(.bold)).foregroundStyle(AppColors.grass)
            }
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(people.count) members: \(people.map(\.name).joined(separator: ", "))")
        .accessibilityHint("Opens members, invitations and group settings")
    }
}

/// People seated at one fire on the existing dusk meadow. At most eight
/// seats; callers show the rest in a list. Purely visual — the list beneath
/// is the accessible equivalent, so the scene is hidden from VoiceOver.
struct StudyFireScene: View {
    let seated: [(person: StudyPerson, session: StudySession)]
    var height: CGFloat = 180
    var onSelect: (UUID) -> Void = { _ in }

    private var count: Int { min(seated.count, 8) }
    private var shepherdSize: CGFloat { count > 4 ? 52 : (count > 2 ? 60 : 72) }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                Image(AssetSlot.Farm.sharedMeadowDusk).resizable().interpolation(.high)
                    .aspectRatio(contentMode: .fill).frame(width: size.width, height: size.height).clipped()
                if count > 0 {
                    PaperCampfire().frame(width: count > 4 ? 44 : 56, height: count > 4 ? 44 : 56)
                        .position(x: size.width * CampfireRules.fire.x, y: size.height * CampfireRules.fire.y - 18)
                }
                ForEach(0..<count, id: \.self) { index in
                    let entry = seated[index]
                    let point = seat(index: index, count: count)
                    Ellipse().fill(AppColors.farmContactShadow.opacity(0.28)).frame(width: shepherdSize * 0.5, height: 7)
                        .position(x: point.x * size.width, y: point.y * size.height)
                    Button { onSelect(entry.person.id) } label: {
                        SlumberPartySocialAvatarView(presentation: entry.person.presentation, avatarID: "shepherd", size: shepherdSize, showsBackdrop: false)
                    }
                    .buttonStyle(.plain)
                    .position(x: point.x * size.width, y: point.y * size.height - shepherdSize * 0.42)
                    Text(entry.person.name)
                        .font(AppTypography.caption.weight(.semibold)).dynamicTypeSize(...DynamicTypeSize.large).lineLimit(1)
                        .foregroundStyle(AppColors.ink).padding(.horizontal, AppSpacing.xs)
                        .background(AppColors.paper.opacity(0.9), in: Capsule())
                        .position(x: point.x * size.width, y: point.y * size.height + 12)
                }
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(AppColors.stroke.opacity(0.35), lineWidth: 1))
        .accessibilityHidden(true)
    }

    /// Compact seating around the fire. Two rows keep eight people legible on
    /// a small phone without panning; the production wide-canvas rule can
    /// replace this once integrated.
    private func seat(index: Int, count: Int) -> CGPoint {
        if count <= 2 { let p = CampfireRules.seat(index: index, count: count); return CGPoint(x: p.x, y: p.y) }
        let perRow = count <= 4 ? count : Int(ceil(Double(count) / 2))
        let row = index / perRow
        let column = index % perRow
        let inRow = row == 0 ? perRow : count - perRow
        let x = (Double(column) + 1) / Double(inRow + 1)
        return CGPoint(x: 0.08 + x * 0.84, y: row == 0 ? 0.50 : 0.80)
    }
}

/// One session in list form. Private rows show the planned end; public rows
/// only show a coarse remaining band.
struct StudySessionRow: View {
    let person: StudyPerson
    let session: StudySession
    let now: Date
    var showsChevron = true
    let onOpen: () -> Void

    private var timing: String {
        if session.ended { return "Finished" }
        if person.audience.isPublic { return session.remainingBand(at: now).prefix(1).uppercased() + session.remainingBand(at: now).dropFirst() }
        return "Until \(session.endsAt.formatted(date: .omitted, time: .shortened))"
    }

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .center, spacing: AppSpacing.sm) {
                SlumberPartySocialAvatarView(presentation: person.presentation, avatarID: "shepherd", size: 44)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(person.isMe ? "You" : person.name).font(AppTypography.headline)
                    Text("\(session.title) · \(timing)").font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    if let intention = session.intention, !intention.isEmpty {
                        Text("“\(intention)”").font(AppTypography.caption).foregroundStyle(AppColors.ink).fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: AppSpacing.xs)
                if session.encouragementCount > 0 {
                    Label("\(session.encouragementCount)", systemImage: "hands.clap").font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                        .accessibilityLabel("\(session.encouragementCount) encouragements")
                }
                if showsChevron { Image(systemName: "chevron.right").font(AppTypography.caption.weight(.bold)).foregroundStyle(AppColors.grass).accessibilityHidden(true) }
            }
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens their session card")
    }
}

/// Loading, failure and staleness look the same in both places; only the
/// wording names the place. Presence is never drawn from a stale record.
struct StudyDataStateNotice: View {
    let state: StudyDataState
    let now: Date
    var placeName: String
    var onRetry: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var capitalizedPlace: String { placeName.prefix(1).uppercased() + placeName.dropFirst() }

    var body: some View {
        switch state {
        case .current:
            EmptyView()
        case .loading:
            HStack(spacing: AppSpacing.sm) {
                ProgressView().controlSize(.small)
                Text("Bringing \(placeName) into view…").font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
            }
            .frame(minHeight: 44)
        case let .failed(reason):
            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Label("\(capitalizedPlace) couldn’t be updated", systemImage: "wifi.exclamationmark").font(AppTypography.headline)
                    Text(reason).font(AppTypography.caption).foregroundStyle(AppColors.secondaryText).fixedSize(horizontal: false, vertical: true)
                    StudySecondaryButton(title: "Try again", symbol: "arrow.clockwise", action: onRetry)
                }
            }
        case let .stale(lastObservedAt):
            let minutes = max(1, Int(now.timeIntervalSince(lastObservedAt) / 60))
            let message = Text("Last seen \(minutes) min ago. Nobody is shown as here now until \(placeName) refreshes.")
                .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
            let refresh = Button("Refresh", action: onRetry).font(AppTypography.caption.weight(.semibold)).tint(AppColors.grass).frame(minHeight: 44)
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Label { message } icon: { Image(systemName: "clock.arrow.circlepath").foregroundStyle(AppColors.warning) }
                    refresh
                }
            } else {
                HStack(alignment: .top, spacing: AppSpacing.xs) {
                    Image(systemName: "clock.arrow.circlepath").foregroundStyle(AppColors.warning).accessibilityHidden(true)
                    message.fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    refresh
                }
            }
        }
    }
}

struct StudySheepRow: View {
    let definitionID: String
    let name: String
    let detail: String
    var actionTitle: String?
    var isBusy = false
    var action: () -> Void = {}

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            PixelAssetImage(name: SheepCatalog.definition(for: definitionID)?.assetName ?? AssetSlot.Sheep.common)
                .frame(width: 48, height: 48).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(name).font(AppTypography.headline)
                Text(detail).font(AppTypography.caption).foregroundStyle(AppColors.secondaryText).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: AppSpacing.xs)
            if let actionTitle {
                Button(actionTitle, action: action).buttonStyle(PixelChipButtonStyle(isSelected: isBusy))
                    .frame(maxWidth: 150, minHeight: 44).disabled(isBusy)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Shows the most recent semantic intent so a reviewer sees what a tap asked for.
struct StudyActionToast: View {
    @ObservedObject var log: SocialStudyActionLog
    var body: some View {
        if let latest = log.latest {
            Text(latest).font(AppTypography.caption).foregroundStyle(AppColors.ink).lineLimit(3)
                .padding(AppSpacing.sm).frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.md))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.md).stroke(AppColors.stroke.opacity(0.3), lineWidth: 1))
                .padding(.horizontal, AppSpacing.md)
                .accessibilityLabel("Prototype action recorded: \(latest)")
        }
    }
}
#endif
