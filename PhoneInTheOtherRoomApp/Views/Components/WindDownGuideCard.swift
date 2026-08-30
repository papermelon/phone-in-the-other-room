import SwiftUI

struct WindDownGuideCard: View {
    let item: WindDownGuidanceItem
    var compact = false
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: compact ? AppSpacing.xs : AppSpacing.sm) {
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(AppColors.grass)
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text(compact ? "OPTIONAL IDEA" : "WHY THIS MAY HELP")
                            .font(pixelFont(.caption))
                            .foregroundStyle(AppColors.grass)
                        Text(item.title)
                            .font(compact ? AppTypography.headline : AppTypography.title)
                    }
                    Spacer(minLength: 0)
                }
                Text(compact ? item.suggestion : item.body)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(compact ? "A small invitation. Keep what feels useful." : "Optional. Keep what feels useful.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                NavigationLink("Read this idea") {
                    WindDownGuidanceDetailView(item: item)
                }
                .font(AppTypography.caption.weight(.semibold))
                .foregroundStyle(AppColors.grass)
                if let onDismiss {
                    Button("Not now", action: onDismiss)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                        .accessibilityHint("Hides this Home idea for a while")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Optional guidance: \(item.title)")
    }
}

struct WindDownRoutineEditor: View {
    @Binding var eveningSteps: [WindDownRoutineStep]
    @Binding var morningSteps: [WindDownRoutineStep]
    var onChange: () -> Void = {}

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var focusedCustomStepID: UUID?
    @State private var rawDrafts: [UUID: String] = [:]
    @State private var expandedEveningGroups: Set<EveningRoutineGroup> = []

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            routineSection(
                title: "After the phone goes away",
                detail: "Choose up to three familiar evening ideas, in the order you want them.",
                phase: .evening,
                steps: $eveningSteps
            )
            routineSection(
                title: "How would you like to start the morning?",
                detail: "Choose one or two things you’d like to do before your phone gets your attention.",
                phase: .morning,
                steps: $morningSteps
            )
            Text("Ideas are invitations. Counting Sheep does not track whether you do them.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.muted)
        }
        .onChange(of: focusedCustomStepID) { oldValue, _ in
            if let oldValue { commitDraft(for: oldValue) }
        }
        .onDisappear { commitAllDrafts() }
    }

    private func routineSection(
        title: String,
        detail: String,
        phase: WindDownRoutinePhase,
        steps: Binding<[WindDownRoutineStep]>
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.headline)
            Text(detail)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.muted)
                .fixedSize(horizontal: false, vertical: true)

            if phase == .evening {
                fixedPhoneStep
            }

            ForEach(Array(steps.wrappedValue.enumerated()), id: \.element.id) { index, step in
                routineRow(step: step, index: index, phase: phase, steps: steps)
            }

            if steps.wrappedValue.count < limit(for: phase) {
                addCustomButton(phase: phase, steps: steps)
                if phase == .evening {
                    eveningSuggestionCatalog(steps: steps)
                } else {
                    morningSuggestionCatalog(steps: steps)
                }
            } else {
                Text("Your sequence is full. Use the More menu on an idea to move or remove it.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }

            if phase == .evening {
                NavigationLink("About these ideas and sources") {
                    WindDownGuideView()
                }
                .font(AppTypography.caption.weight(.semibold))
                .foregroundStyle(AppColors.grass)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func addCustomButton(
        phase: WindDownRoutinePhase,
        steps: Binding<[WindDownRoutineStep]>
    ) -> some View {
        Button {
            let custom = WindDownRoutineStep.custom("", phase: phase)
            steps.wrappedValue.append(custom)
            focusedCustomStepID = custom.id
            onChange()
        } label: {
            Label("Add my own", systemImage: "plus.circle.fill")
                .font(AppTypography.body.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(PixelChipButtonStyle(isSelected: false))
        .accessibilityHint("Adds a custom activity with a maximum of 80 characters")
    }

    private func eveningSuggestionCatalog(
        steps: Binding<[WindDownRoutineStep]>
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            ForEach(EveningRoutineGroup.allCases) { group in
                DisclosureGroup(isExpanded: expandedBinding(for: group)) {
                    VStack(spacing: AppSpacing.xxs) {
                        ForEach(group.activities) { activity in
                            suggestionButton(activity, phase: .evening, steps: steps, compact: true)
                        }
                    }
                    .padding(.top, AppSpacing.xs)
                } label: {
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text(group.title)
                            .font(AppTypography.body.weight(.semibold))
                        Text(group.detail)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(minHeight: 44, alignment: .leading)
                }
                .tint(AppColors.grass)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xxs)
                .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.md))
            }
        }
    }

    private func morningSuggestionCatalog(
        steps: Binding<[WindDownRoutineStep]>
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Morning ideas")
                .font(AppTypography.caption.weight(.semibold))
                .foregroundStyle(AppColors.muted)

            LazyVGrid(columns: suggestionColumns, alignment: .leading, spacing: AppSpacing.xs) {
                ForEach(PhoneFreeActivity.morningChoices.filter { $0 != .journal }) { activity in
                    suggestionButton(activity, phase: .morning, steps: steps)
                }
            }

            DisclosureGroup("One more idea") {
                suggestionButton(.journal, phase: .morning, steps: steps, compact: true)
                    .padding(.top, AppSpacing.xs)
            }
            .font(AppTypography.caption.weight(.semibold))
            .tint(AppColors.grass)
            .frame(minHeight: 44)
        }
    }

    private func suggestionButton(
        _ activity: PhoneFreeActivity,
        phase: WindDownRoutinePhase,
        steps: Binding<[WindDownRoutineStep]>,
        compact: Bool = false
    ) -> some View {
        let selected = steps.wrappedValue.contains {
            $0.kind == .suggestion && $0.activity == activity
        }
        return Button {
            guard !selected, steps.wrappedValue.count < limit(for: phase) else { return }
            steps.wrappedValue.append(.suggested(activity, phase: phase))
            onChange()
        } label: {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: activity.systemImage)
                    .foregroundStyle(AppColors.grass)
                    .frame(width: 22)
                    .accessibilityHidden(true)
                Text(activity.title)
                    .font(compact ? AppTypography.caption.weight(.semibold) : AppTypography.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: selected ? "checkmark.circle.fill" : "plus.circle")
                    .foregroundStyle(selected ? AppColors.grass : AppColors.muted)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, AppSpacing.sm)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: AppRadius.sm))
        }
        .buttonStyle(.plain)
        .disabled(selected)
        .opacity(selected ? 0.58 : 1)
        .accessibilityLabel(selected ? "Added idea: \(activity.title)" : "Add idea: \(activity.title)")
    }

    private func expandedBinding(for group: EveningRoutineGroup) -> Binding<Bool> {
        Binding(
            get: { expandedEveningGroups.contains(group) },
            set: { isExpanded in
                if isExpanded {
                    expandedEveningGroups.insert(group)
                } else {
                    expandedEveningGroups.remove(group)
                }
            }
        )
    }

    private var fixedPhoneStep: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "iphone.slash")
                .foregroundStyle(AppColors.grass)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(WindDownRoutineStep.phoneAwayTitle)
                    .font(AppTypography.body.weight(.semibold))
                Text("Always first")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
            Spacer()
            Image(systemName: "lock.fill")
                .foregroundStyle(AppColors.muted)
                .accessibilityHidden(true)
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Put phone away, always first")
    }

    @ViewBuilder
    private func routineRow(
        step: WindDownRoutineStep,
        index: Int,
        phase: WindDownRoutinePhase,
        steps: Binding<[WindDownRoutineStep]>
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(alignment: .center, spacing: AppSpacing.xs) {
                Text("\(index + 1)")
                    .font(AppTypography.caption.weight(.bold))
                    .foregroundStyle(AppColors.grass)
                    .frame(width: 24, height: 24)
                    .background(AppColors.grass.opacity(0.12), in: Circle())
                    .accessibilityHidden(true)

                if step.kind == .custom {
                    TextField(
                        "Write a familiar activity",
                        text: Binding(
                            get: { rawDrafts[step.id] ?? step.customText ?? "" },
                            set: { rawDrafts[step.id] = String($0.prefix(PhoneFreeCue.maximumTextLength)) }
                        ),
                        axis: .vertical
                    )
                    .font(AppTypography.body)
                    .lineLimit(1...3)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .padding(AppSpacing.xs)
                    .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.sm))
                    .accessibilityLabel("Custom \(phase == .evening ? "evening" : "morning") idea \(index + 1)")
                    .focused($focusedCustomStepID, equals: step.id)
                    .submitLabel(.done)
                    .onSubmit { commitDraft(for: step.id) }
                } else {
                    Text(step.title)
                        .font(AppTypography.body.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                routineMenu(step: step, index: index, steps: steps)
            }

            if let activity = step.activity {
                Text(activity.onboardingRationale)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 32)
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(phase == .evening ? "Evening" : "Morning") idea \(index + 1) of \(steps.wrappedValue.count)")
    }

    private func routineMenu(
        step: WindDownRoutineStep,
        index: Int,
        steps: Binding<[WindDownRoutineStep]>
    ) -> some View {
        Menu {
            if steps.wrappedValue.count > 1 {
                Button("Move earlier", systemImage: "arrow.up") {
                    guard index > 0 else { return }
                    steps.wrappedValue.swapAt(index, index - 1)
                    onChange()
                }
                .disabled(index == 0)

                Button("Move later", systemImage: "arrow.down") {
                    guard index + 1 < steps.wrappedValue.count else { return }
                    steps.wrappedValue.swapAt(index, index + 1)
                    onChange()
                }
                .disabled(index + 1 == steps.wrappedValue.count)
            }

            Button("Remove", systemImage: "trash", role: .destructive) {
                rawDrafts.removeValue(forKey: step.id)
                steps.wrappedValue.remove(at: index)
                onChange()
            }
        } label: {
            Image(systemName: "ellipsis")
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("More actions for \(step.title)")
        .accessibilityHint(
            steps.wrappedValue.count > 1
                ? "Move this idea earlier or later, or remove it"
                : "Remove this idea"
        )
    }

    /// Commits only when editing ends so a trailing space remains available to
    /// the TextEditor. Empty custom ideas use the existing remove semantics.
    private func commitDraft(for id: UUID) {
        guard let raw = rawDrafts.removeValue(forKey: id) else { return }
        if let index = eveningSteps.firstIndex(where: { $0.id == id }) {
            commit(raw, at: index, phase: .evening, in: &eveningSteps)
        } else if let index = morningSteps.firstIndex(where: { $0.id == id }) {
            commit(raw, at: index, phase: .morning, in: &morningSteps)
        }
    }

    private func commit(
        _ raw: String,
        at index: Int,
        phase: WindDownRoutinePhase,
        in steps: inout [WindDownRoutineStep]
    ) {
        let id = steps[index].id
        guard let normalized = PhoneFreeCue.normalized(raw) else {
            steps.remove(at: index)
            onChange()
            return
        }
        steps[index] = .custom(normalized, phase: phase, id: id)
        onChange()
    }

    private func commitAllDrafts() {
        for id in Array(rawDrafts.keys) { commitDraft(for: id) }
    }

    private func limit(for phase: WindDownRoutinePhase) -> Int {
        phase == .evening
            ? WindDownRoutineStep.maximumEveningCount
            : WindDownRoutineStep.maximumMorningCount
    }

    private var suggestionColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.adaptive(minimum: 155), spacing: AppSpacing.xs)]
    }
}

private enum EveningRoutineGroup: String, CaseIterable, Identifiable {
    case closeDay
    case getReady
    case slowDown
    case cosy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .closeDay: return "Close the day"
        case .getReady: return "Get ready for sleep"
        case .slowDown: return "Slow things down"
        case .cosy: return "Make something cosy"
        }
    }

    var detail: String {
        switch self {
        case .closeDay: return "Give tomorrow a place, then leave it there."
        case .getReady: return "Let a familiar routine mark the transition."
        case .slowDown: return "Choose something quieter for your attention."
        case .cosy: return "Make offline time feel inviting."
        }
    }

    var activities: [PhoneFreeActivity] {
        switch self {
        case .closeDay: return [.journal, .prepareTomorrow, .brainDump]
        case .getReady: return [.brushTeeth, .shower, .sleepwear]
        case .slowDown: return [.read, .stretch, .relaxation, .quietMusic]
        case .cosy: return [.makeTea, .quietConversation, .calmHobby]
        }
    }
}

struct WindDownHowItWorksView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                OllieRitualView(state: .ready, presentation: .cardCompanion)
                    .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("HOW WIND DOWN WORKS")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text("One small ritual around sleep.")
                        .font(AppTypography.display(30))
                    Text("Counting Sheep helps you make the phone-away choice, fill the quiet with something offline, and keep the first part of morning phone-free.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.muted)
                }
                OnboardingTimeline(draft: OnboardingDraft())
                howCard(
                    icon: "iphone.slash",
                    title: "Protect",
                    detail: "Selected apps can be limited from Wind Down start through morning quiet. Counting Sheep stays available."
                )
                howCard(
                    icon: "book.closed.fill",
                    title: "Replace",
                    detail: "Choose up to three evening ideas and two morning ideas. They are invitations, never tasks."
                )
                howCard(
                    icon: "sparkles",
                    title: "Learn",
                    detail: "A small, optional guide offers sourced ideas about screens, light, timing, and settling. It never becomes a feed or a score."
                )
                Text("Change your schedule, apps, Wind Down tag, and reminders in Your Wind Down.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("How Wind Down works")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func howCard(icon: String, title: String, detail: String) -> some View {
        PixelCard {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                Image(systemName: icon)
                    .font(.title2.weight(.black))
                    .foregroundStyle(AppColors.grass)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(title).font(AppTypography.headline)
                    Text(detail)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.secondaryText)
                }
            }
        }
    }
}

#Preview("Guide card") {
    WindDownGuideCard(item: WindDownGuidanceLibrary.items[0])
        .padding()
        .background(AppColors.paper)
}

#Preview("Routine rows · accessibility Dynamic Type") {
    WindDownRoutineEditor(
        eveningSteps: .constant([
            .suggested(.read, phase: .evening),
            .custom("Write one thought down", phase: .evening)
        ]),
        morningSteps: .constant([.suggested(.openCurtains, phase: .morning)])
    )
    .padding(AppSpacing.md)
    .background(AppColors.paper)
    .environment(\.dynamicTypeSize, .accessibility3)
}
