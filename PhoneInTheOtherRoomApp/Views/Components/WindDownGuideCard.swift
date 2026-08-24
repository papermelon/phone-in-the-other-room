import SwiftUI

struct WindDownGuideCard: View {
    let item: WindDownGuidanceItem
    var compact = false

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: compact ? AppSpacing.xs : AppSpacing.sm) {
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(AppColors.grass)
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text("WHY THIS MAY HELP")
                            .font(pixelFont(.caption))
                            .foregroundStyle(AppColors.grass)
                        Text(item.title)
                            .font(compact ? AppTypography.headline : AppTypography.title)
                    }
                    Spacer(minLength: 0)
                }
                Text(item.body)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Optional. Keep what feels useful.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                NavigationLink("About these ideas and sources") {
                    WindDownGuideView()
                }
                .font(AppTypography.caption.weight(.semibold))
                .foregroundStyle(AppColors.grass)
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

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            routineSection(
                title: "In the evening",
                detail: "Put the phone away first. Add up to three private ideas for the quiet that follows.",
                phase: .evening,
                steps: $eveningSteps
            )
            routineSection(
                title: "After waking",
                detail: "Add up to two private ideas for your morning quiet, or leave this part empty.",
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
                Text("Suggested ideas")
                    .font(AppTypography.caption.weight(.semibold))
                    .foregroundStyle(AppColors.muted)
                LazyVGrid(columns: suggestionColumns, alignment: .leading, spacing: AppSpacing.xs) {
                    ForEach(choices(for: phase)) { activity in
                        let selected = steps.wrappedValue.contains {
                            $0.kind == .suggestion && $0.activity == activity
                        }
                        Button {
                            guard !selected, steps.wrappedValue.count < limit(for: phase) else { return }
                            steps.wrappedValue.append(
                                .suggested(activity, phase: phase)
                            )
                            onChange()
                        } label: {
                            Text(activity.title)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(PixelChipButtonStyle(isSelected: selected))
                        .disabled(selected)
                        .accessibilityLabel(selected ? "Added idea: \(activity.title)" : "Add idea: \(activity.title)")
                    }
                }

                Button {
                    steps.wrappedValue.append(.custom("", phase: phase))
                    onChange()
                } label: {
                    Label("Add a custom idea", systemImage: "plus")
                        .font(AppTypography.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(PixelChipButtonStyle(isSelected: false))
            } else {
                Text("Your sequence is full. You can move or remove ideas below.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }

            if phase == .evening || !steps.wrappedValue.isEmpty {
                NavigationLink("About these ideas and sources") {
                    WindDownGuideView()
                }
                .font(AppTypography.caption.weight(.semibold))
                .foregroundStyle(AppColors.grass)
            }
        }
        .accessibilityElement(children: .contain)
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
            HStack(alignment: .top, spacing: AppSpacing.xs) {
                Text("\(index + 1)")
                    .font(AppTypography.caption.weight(.bold))
                    .foregroundStyle(AppColors.grass)
                    .frame(width: 24, height: 24)
                    .background(AppColors.grass.opacity(0.12), in: Circle())
                    .accessibilityHidden(true)

                if step.kind == .custom {
                    TextEditor(
                        text: Binding(
                            get: { rawDrafts[step.id] ?? step.customText ?? "" },
                            set: { rawDrafts[step.id] = $0 }
                        )
                    )
                    .font(AppTypography.body)
                    .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
                    .scrollContentBackground(.hidden)
                    .padding(AppSpacing.xs)
                    .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.sm))
                    .accessibilityLabel("Custom \(phase == .evening ? "evening" : "morning") idea \(index + 1)")
                    .focused($focusedCustomStepID, equals: step.id)
                } else {
                    Text(step.title)
                        .font(AppTypography.body.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

            }

            Text("Order")
                .font(AppTypography.caption.weight(.semibold))
                .foregroundStyle(AppColors.muted)
            reorderControls(step: step, index: index, steps: steps)

            HStack(spacing: AppSpacing.sm) {
                Button("Remove \(step.title)", role: .destructive) {
                    steps.wrappedValue.remove(at: index)
                    onChange()
                }
                .font(AppTypography.caption)
                .frame(minHeight: 44)
                Spacer()
            }

            if let guidanceID = step.guidanceID,
               let item = WindDownGuidanceLibrary.items.first(where: { $0.id == guidanceID }) {
                WindDownGuideCard(item: item, compact: true)
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                .stroke(AppColors.stroke.opacity(0.35), lineWidth: 1.5)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(phase == .evening ? "Evening" : "Morning") idea \(index + 1) of \(steps.wrappedValue.count)")
    }

    private func reorderControls(
        step: WindDownRoutineStep,
        index: Int,
        steps: Binding<[WindDownRoutineStep]>
    ) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Button {
                guard index > 0 else { return }
                steps.wrappedValue.swapAt(index, index - 1)
                onChange()
            } label: {
                Image(systemName: "chevron.up")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.bordered)
            .disabled(index == 0)
            .accessibilityLabel("Move \(step.title) up, item \(index + 1) of \(steps.wrappedValue.count)")
            .accessibilityHint(index == 0 ? "Already first" : "Moves this idea earlier")

            Button {
                guard index + 1 < steps.wrappedValue.count else { return }
                steps.wrappedValue.swapAt(index, index + 1)
                onChange()
            } label: {
                Image(systemName: "chevron.down")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.bordered)
            .disabled(index + 1 == steps.wrappedValue.count)
            .accessibilityLabel("Move \(step.title) down, item \(index + 1) of \(steps.wrappedValue.count)")
            .accessibilityHint(index + 1 == steps.wrappedValue.count ? "Already last" : "Moves this idea later")
        }
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

    private func choices(for phase: WindDownRoutinePhase) -> [PhoneFreeActivity] {
        phase == .evening ? PhoneFreeActivity.eveningChoices : PhoneFreeActivity.morningChoices
    }

    private var suggestionColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible()), GridItem(.flexible())]
    }
}

struct WindDownGuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("WIND DOWN GUIDE")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text("Small ideas for a kinder relationship with screens and sleep.")
                        .font(AppTypography.display(30))
                    Text("These are gentle ideas, not a treatment plan. Keep what feels useful and leave the rest.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.muted)
                }

                ForEach(WindDownGuidanceTopic.allCases) { topic in
                    let topicItems = WindDownGuidanceLibrary.items(for: topic)
                    if !topicItems.isEmpty {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text(topic.title)
                                .font(AppTypography.headline)
                            ForEach(topicItems) { item in
                                guideItem(item)
                            }
                        }
                    }
                }

                PixelCard {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("A note about sleep support")
                            .font(AppTypography.headline)
                        Text("Counting Sheep is not a sleep clinic or an insomnia treatment. If sleep difficulties keep affecting your days, a healthcare professional or CBT-I provider can help you find the right support.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.muted)
                    }
                }
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("About these ideas and sources")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func guideItem(_ item: WindDownGuidanceItem) -> some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(item.title)
                    .font(AppTypography.headline)
                Text(item.body)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.secondaryText)
                Text(sourceLabel(for: item))
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
        }
    }

    private func sourceLabel(for item: WindDownGuidanceItem) -> String {
        let label = WindDownGuidanceSourcePresentation.combinedLabel(for: item)
        return label == "Counting Sheep guidance" ? label : "Sources: " + label
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

#Preview("Guide") {
    NavigationStack {
        WindDownGuideView()
    }
}
