import SwiftUI

struct QuietTimeEditorView: View {
    enum Mode {
        case oneTime(UUID?)
        case routine(UUID?)
    }

    private enum RepeatChoice: String, CaseIterable, Identifiable {
        case daily
        case weekdays
        case custom

        var id: String { rawValue }
        var title: String {
            switch self {
            case .daily: return "Daily"
            case .weekdays: return "Weekdays"
            case .custom: return "Custom days"
            }
        }
    }

    @EnvironmentObject private var viewModel: FocusRunViewModel
    @Environment(\.dismiss) private var dismiss
    let mode: Mode
    let onComplete: (Bool) -> Void

    @State private var title = "One-time quiet period"
    @State private var starts: Date
    @State private var ends: Date
    @State private var repeatChoice: RepeatChoice = .daily
    @State private var selectedWeekdays = Set(2...6)
    @State private var enabled = true
    @State private var error: String?

    init(mode: Mode, onComplete: @escaping (Bool) -> Void, initialError: String? = nil) {
        let defaultWindow = QuietPeriodScheduling.defaultWindow()
        self.mode = mode
        self.onComplete = onComplete
        _starts = State(initialValue: defaultWindow.start)
        _ends = State(initialValue: defaultWindow.end)
        _error = State(initialValue: initialError)
    }

    private var routineID: UUID? {
        if case let .routine(id) = mode { return id }
        return nil
    }

    private var oneTimeID: UUID? {
        if case let .oneTime(id) = mode { return id }
        return nil
    }

    private var isNewOneTime: Bool {
        if case .oneTime(nil) = mode { return true }
        return false
    }

    private var isNewRoutine: Bool {
        if case .routine(nil) = mode { return true }
        return false
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                intro
                detailsCard
                if routineID != nil || isNewRoutine { recurrenceCard }
                if let error {
                    PixelCard {
                        Label {
                            Text(error)
                                .font(AppTypography.caption)
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "leaf.fill")
                                .foregroundStyle(AppColors.warning)
                        }
                    }
                }
                actions
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle(isNewOneTime || isNewRoutine ? "Add quiet time" : "Edit quiet time")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .onAppear(perform: load)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(isNewOneTime ? "Plan a little room for quiet." : "Quiet time settings")
                .font(AppTypography.title)
            Text(isNewOneTime
                ? "Choose a future window. Starting now is a separate, one-tap quiet flow."
                : "Keep this quiet period comfortable and easy to change.")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.muted)
        }
    }

    private var detailsCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Quiet time")
                    .font(AppTypography.headline)
                TextField("Name", text: $title)
                    .font(AppTypography.body)
                    .padding(AppSpacing.sm)
                    .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.sm))
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.sm).stroke(AppColors.stroke.opacity(0.18), lineWidth: 1))
                    .accessibilityLabel("Quiet time name")
                dateRow("Starts", selection: $starts, range: nil)
                dateRow("Ends", selection: $ends, range: starts...)
                if oneTimeID != nil {
                    Toggle("Enabled", isOn: $enabled)
                        .tint(AppColors.grass)
                }
            }
        }
    }

    private var recurrenceCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Repeats")
                    .font(AppTypography.headline)
                PixelSegmentedPicker(
                    title: "Repeat pattern",
                    selection: $repeatChoice,
                    label: { $0.title }
                )
                if repeatChoice == .custom { weekdayPicker }
                Toggle("Enabled", isOn: $enabled)
                    .tint(AppColors.grass)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: AppSpacing.sm) {
            Button(primaryActionTitle) { save() }
                .frame(maxWidth: .infinity)
                .buttonStyle(PixelPrimaryButtonStyle())
            if let oneTimeID {
                Button("Cancel this quiet time", role: .destructive) {
                    viewModel.cancelOneTimeQuiet(id: oneTimeID)
                    dismiss()
                }
                .frame(minHeight: 44)
                .font(AppTypography.body)
            }
            if let routineID {
                Button("Cancel this repeating time", role: .destructive) {
                    viewModel.cancelAdditionalRoutine(id: routineID)
                    dismiss()
                }
                .frame(minHeight: 44)
                .font(AppTypography.body)
            }
        }
    }

    private var primaryActionTitle: String {
        return isNewOneTime || isNewRoutine ? "Save quiet time" : "Save changes"
    }

    private func dateRow(_ label: String, selection: Binding<Date>, range: PartialRangeFrom<Date>?) -> some View {
        HStack(alignment: .center) {
            Text(label)
                .font(AppTypography.body)
            Spacer(minLength: AppSpacing.sm)
            if let range {
                DatePicker("", selection: selection, in: range, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
            } else {
                DatePicker("", selection: selection, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
            }
        }
        .frame(minHeight: 44)
    }

    private var weekdayPicker: some View {
        let labels = Calendar.current.shortWeekdaySymbols
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: AppSpacing.xs) {
            ForEach(1...7, id: \.self) { day in
                Button(labels[day - 1]) {
                    if selectedWeekdays.contains(day) {
                        selectedWeekdays.remove(day)
                    } else {
                        selectedWeekdays.insert(day)
                    }
                }
                .buttonStyle(PixelChipButtonStyle(isSelected: selectedWeekdays.contains(day)))
                .accessibilityLabel(labels[day - 1])
                .accessibilityValue(selectedWeekdays.contains(day) ? "Selected" : "Not selected")
            }
        }
    }

    private func load() {
        if let oneTimeID,
           let item = viewModel.windDownSchedule.oneTimePeriods.first(where: { $0.id == oneTimeID }) {
            title = item.title
            starts = item.interval.start
            ends = item.interval.end
            enabled = item.enabled
        }
        if let routineID,
           let routine = viewModel.windDownSchedule.routines.first(where: { $0.id == routineID }) {
            title = routine.title
            let calendar = Calendar.current
            starts = routine.start.date(on: Date(), calendar: calendar)
            ends = routine.end.date(on: Date(), calendar: calendar)
            if ends <= starts {
                ends = calendar.date(byAdding: .day, value: 1, to: ends)
                    ?? ends.addingTimeInterval(24 * 60 * 60)
            }
            selectedWeekdays = Set(routine.weekdays)
            repeatChoice = repeatChoice(for: routine.recurrence)
            enabled = routine.enabled
        }
    }

    private func repeatChoice(for recurrence: WindDownRecurrence) -> RepeatChoice {
        switch recurrence {
        case .daily: return .daily
        case .weekdays: return .weekdays
        case .custom: return .custom
        }
    }

    private func selectedRecurrence() -> WindDownRecurrence {
        switch repeatChoice {
        case .daily: return .daily
        case .weekdays: return .weekdays
        case .custom: return .custom(selectedWeekdays.sorted())
        }
    }

    private func save() {
        let calendar = Calendar.current
        if let oneTimeID {
            let success = viewModel.updateOneTimeQuiet(
                id: oneTimeID,
                title: title,
                start: starts,
                end: ends,
                enabled: enabled
            )
            onComplete(success)
            if success { dismiss() }
            else { error = viewModel.windDownScheduleError ?? "Choose a future window that does not overlap another quiet time." }
            return
        }
        if isNewOneTime {
            let success = viewModel.addOneTimeAdditionalQuiet(title: title, start: starts, end: ends)
            onComplete(success)
            if success { dismiss() }
            else { error = viewModel.windDownScheduleError ?? "Choose a future window that does not overlap another quiet time." }
            return
        }
        let start = WindDownClockTime(
            hour: calendar.component(.hour, from: starts),
            minute: calendar.component(.minute, from: starts)
        )
        let end = WindDownClockTime(
            hour: calendar.component(.hour, from: ends),
            minute: calendar.component(.minute, from: ends)
        )
        let selectedRecurrence = selectedRecurrence()
        let success: Bool
        if let routineID {
            success = viewModel.updateAdditionalRoutine(
                id: routineID,
                title: title,
                start: start,
                end: end,
                recurrence: selectedRecurrence,
                enabled: enabled
            )
        } else {
            success = viewModel.addAdditionalWindDown(
                title: title,
                start: start,
                end: end,
                recurrence: selectedRecurrence
            )
        }
        onComplete(success)
        if success { dismiss() }
        else { error = viewModel.windDownScheduleError ?? "That repeat overlaps another quiet time. Choose a different window." }
    }
}

#Preview("One-time editor") {
    NavigationStack {
        QuietTimeEditorView(mode: .oneTime(nil), onComplete: { _ in })
            .environmentObject(FocusRunViewModel())
    }
    .preferredColorScheme(.dark)
}

#Preview("One-time editor · Dynamic Type") {
    NavigationStack {
        QuietTimeEditorView(mode: .oneTime(nil), onComplete: { _ in })
            .environmentObject(FocusRunViewModel())
            .environment(\.dynamicTypeSize, .accessibility2)
    }
}

#Preview("One-time editor · overlap/error") {
    NavigationStack {
        QuietTimeEditorView(
            mode: .oneTime(nil),
            onComplete: { _ in },
            initialError: "This quiet time overlaps another period. Choose a different window."
        )
        .environmentObject(FocusRunViewModel())
    }
}
