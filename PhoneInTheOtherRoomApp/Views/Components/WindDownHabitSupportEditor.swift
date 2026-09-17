import SwiftUI

/// Optional planning support stays a draft until the person explicitly saves Plan.
struct WindDownHabitSupportEditor: View {
    @Binding var plan: WindDownHabitPlan
    var initialFocus: WindDownHabitEditFocus? = nil
    @State private var isExpanded = false
    @FocusState private var focusedField: Field?

    init(plan: Binding<WindDownHabitPlan>, initialFocus: WindDownHabitEditFocus? = nil) {
        _plan = plan
        self.initialFocus = initialFocus
        _isExpanded = State(initialValue: initialFocus != nil && initialFocus != .activity)
    }

    private enum Field: Hashable { case cue, preparation, smallerVersion }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                field(
                    "A familiar moment to begin",
                    placeholder: "After I brush my teeth",
                    text: textBinding(\.cue),
                    focus: .cue,
                    limit: WindDownHabitPlan.maximumContextLength
                )
                field(
                    "Something to get ready beforehand",
                    placeholder: "Leave my book beside the chair",
                    text: textBinding(\.preparation),
                    focus: .preparation,
                    limit: WindDownHabitPlan.maximumContextLength
                )
                field(
                    "A smaller version for a difficult evening",
                    placeholder: "Read one paragraph",
                    text: textBinding(\.smallerActivity),
                    focus: .smallerVersion,
                    limit: WindDownHabitPlan.maximumActivityLength
                )
                Text("Choose the smaller version on Home when you need it. Your schedule and app protection stay the same.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                placementChoices.id("habit-access")
                Text("These details stay private. Your changes are kept when you save your plan or start Wind Down.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
            .padding(.top, AppSpacing.md)
        } label: {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("Make starting easier")
                    .font(AppTypography.headline)
                Text("Optional cues, a smaller version, and a place for your phone.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
            .frame(minHeight: 44, alignment: .leading)
        }
        .tint(AppColors.grass)
        .onAppear {
            guard let initialFocus, initialFocus != .activity else { return }
            isExpanded = true
            switch initialFocus {
            case .cue: focusedField = .cue
            case .preparation: focusedField = .preparation
            case .smallerVersion: focusedField = .smallerVersion
            case .activity, .access: break
            }
        }
    }

    private var placementChoices: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Where will your phone rest?")
                .font(AppTypography.body.weight(.semibold))
            ForEach(WindDownPhonePlacement.allCases, id: \.self) { placement in
                Button {
                    plan.phonePlacement = placement
                } label: {
                    HStack(alignment: .top, spacing: AppSpacing.sm) {
                        Image(systemName: plan.phonePlacement == placement ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(AppColors.grass)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            Text(placement.title)
                                .font(AppTypography.body.weight(.semibold))
                            Text(placement.detail)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(AppSpacing.sm)
                    .frame(minHeight: 44)
                    .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.md))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(plan.phonePlacement == placement ? .isSelected : [])
            }
            Text("Keep essential communication and alerts in mind. Nearby placement uses the same selected-app limits. Choose distracting apps individually and review any selected categories.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.muted)
            NavigationLink("Review app protection") {
                SettingsProtectionTagsView()
            }
            .font(AppTypography.caption.weight(.semibold))
            .foregroundStyle(AppColors.grass)
            .frame(minHeight: 44)
        }
    }

    private func textBinding(_ keyPath: WritableKeyPath<WindDownHabitPlan, String?>) -> Binding<String> {
        Binding(get: { plan[keyPath: keyPath] ?? "" }, set: { plan[keyPath: keyPath] = $0 })
    }

    private func field(_ title: String, placeholder: String, text: Binding<String>, focus: Field, limit: Int) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(AppTypography.body.weight(.semibold))
            TextField(placeholder, text: Binding(
                get: { text.wrappedValue },
                set: { text.wrappedValue = String($0.prefix(limit)) }
            ), axis: .vertical)
            .font(AppTypography.body)
            .lineLimit(1...4)
            .padding(AppSpacing.sm)
            .frame(minHeight: 44)
            .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.sm))
            .focused($focusedField, equals: focus)
            .accessibilityLabel(title)
            .accessibilityHint("Optional, up to \(limit) characters")
        }
        .id("habit-\(String(describing: focus))")
    }
}

#Preview("Habit support · empty") {
    NavigationStack {
        ScrollView {
            WindDownHabitSupportEditor(plan: .constant(WindDownHabitPlan()), initialFocus: .access)
                .padding(AppSpacing.md)
        }
        .background(AppColors.paper)
    }
}

#Preview("Habit support · large text") {
    ScrollView {
        WindDownHabitSupportEditor(
            plan: .constant(WindDownHabitPlan(cue: "After brushing my teeth", preparation: "Leave my book beside the chair", smallerActivity: "Read one paragraph")),
            initialFocus: .access
        )
        .padding(AppSpacing.md)
    }
    .background(AppColors.paper)
    .environment(\.dynamicTypeSize, .accessibility3)
    .preferredColorScheme(.dark)
}
