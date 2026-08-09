import SwiftUI

struct WindDownScheduleView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @State private var editor: Editor?
    @State private var message: String?

    private var upcomingOneTimePeriods: [WindDownOneTimePeriod] {
        viewModel.windDownSchedule.oneTimePeriods
            .filter { $0.cancelledAt == nil && $0.interval.end > Date() }
            .sorted { $0.interval.start < $1.interval.start }
    }

    var body: some View {
        List {
            Section {
                Text("Keep one-time quiet periods ready for the day. They disappear after their window; completed quiet remains in Nights.")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.muted)
            }

            Section("One-time quiet periods") {
                if upcomingOneTimePeriods.isEmpty {
                    Text("No one-time quiet periods are scheduled.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.muted)
                } else {
                    ForEach(upcomingOneTimePeriods) { period in
                        Button { editor = .oneTime(period.id) } label: {
                            scheduleRow(
                                title: period.title,
                                detail: formatted(period.interval),
                                status: viewModel.readyOneTimeQuietPeriodID == period.id ? "Ready now" : nil,
                                enabled: period.enabled
                            )
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Cancel", role: .destructive) {
                                viewModel.cancelOneTimeQuiet(id: period.id)
                            }
                        }
                    }
                }
                Button { editor = .newOneTime } label: {
                    Label("Add one-time quiet period", systemImage: "plus")
                }
            }

            Section("Repeats") {
                let routines = viewModel.windDownSchedule.routines.filter {
                    $0.role == .additionalQuiet
                }
                if routines.isEmpty {
                    Text("No repeating quiet times yet.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.muted)
                } else {
                    ForEach(routines) { routine in
                        Button { editor = .routine(routine.id) } label: {
                            scheduleRow(
                                title: routine.title,
                                detail: "\(routine.recurrence.title) · \(clock(routine.start))–\(clock(routine.end))",
                                enabled: routine.enabled
                            )
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Cancel", role: .destructive) {
                                viewModel.cancelAdditionalRoutine(id: routine.id)
                            }
                        }
                    }
                }
                Button { editor = .newRoutine } label: {
                    Label("Add a repeating quiet time", systemImage: "repeat")
                }
            }

            Section("Usual Wind Down") {
                if let primary = viewModel.windDownSchedule.routines.first(where: {
                    $0.role == .primarySleepBookend
                }) {
                    scheduleRow(
                        title: primary.title,
                        detail: "Every day · \(clock(primary.start))–\(clock(primary.end))",
                        enabled: primary.enabled
                    )
                    Text("Your usual Wind Down spans before bed, overnight, and after waking. Edit its bedtime and wake time in Settings.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                } else {
                    Text("Set up your usual Wind Down in Settings.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.muted)
                }
            }

            if let message {
                Section {
                    Text(message)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.grass)
                }
            }
        }
        .navigationTitle("Upcoming quiet times")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editor) { editor in
            NavigationStack {
                switch editor {
                case .newOneTime:
                    QuietTimeEditorView(mode: .oneTime(nil), onComplete: { success in
                        message = success ? "Ollie saved that quiet time." : "Choose a future window that does not overlap another quiet time."
                    })
                case let .oneTime(id):
                    QuietTimeEditorView(mode: .oneTime(id), onComplete: { success in
                        message = success ? "Ollie updated that quiet time." : "Choose a future window that does not overlap another quiet time."
                    })
                case .newRoutine:
                    QuietTimeEditorView(mode: .routine(nil), onComplete: { success in
                        message = success ? "Ollie saved that repeating quiet time." : "That repeat overlaps another quiet time. Choose a different window."
                    })
                case let .routine(id):
                    QuietTimeEditorView(mode: .routine(id), onComplete: { success in
                        message = success ? "Ollie updated that repeating quiet time." : "That repeat overlaps another quiet time. Choose a different window."
                    })
                }
            }
            .environmentObject(viewModel)
        }
    }

    private func scheduleRow(
        title: String,
        detail: String,
        status: String? = nil,
        enabled: Bool
    ) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: enabled ? "moon.zzz.fill" : "pause.circle")
                .foregroundStyle(enabled ? AppColors.grass : AppColors.muted)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(title).font(AppTypography.headline)
                if let status {
                    Text(status)
                        .font(AppTypography.caption.weight(.bold))
                        .foregroundStyle(AppColors.grass)
                }
                Text(detail).font(AppTypography.caption).foregroundStyle(AppColors.muted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.muted)
        }
        .contentShape(Rectangle())
    }

    private func clock(_ time: WindDownClockTime) -> String {
        String(format: "%02d:%02d", time.hour, time.minute)
    }

    private func formatted(_ interval: DateInterval) -> String {
        "\(interval.start.formatted(date: .abbreviated, time: .shortened)) – \(interval.end.formatted(date: .abbreviated, time: .shortened))"
    }

    private enum Editor: Identifiable {
        case newOneTime
        case oneTime(UUID)
        case newRoutine
        case routine(UUID)

        var id: String {
            switch self {
            case .newOneTime: return "new-one-time"
            case let .oneTime(id): return "one-time-\(id.uuidString)"
            case .newRoutine: return "new-routine"
            case let .routine(id): return "routine-\(id.uuidString)"
            }
        }
    }
}

    private struct QuietTimeEditorView: View {
    enum Mode {
        case oneTime(UUID?)
        case routine(UUID?)
    }

    @EnvironmentObject private var viewModel: FocusRunViewModel
    @Environment(\.dismiss) private var dismiss
    let mode: Mode
    let onComplete: (Bool) -> Void

    @State private var title = "One-time quiet period"
    @State private var starts: Date
    @State private var ends: Date
    @State private var recurrence: WindDownRecurrence = .daily
    @State private var selectedWeekdays = Set(2...6)
    @State private var enabled = true
    @State private var error: String?

    init(mode: Mode, onComplete: @escaping (Bool) -> Void) {
        let defaultWindow = QuietPeriodScheduling.defaultWindow()
        self.mode = mode
        self.onComplete = onComplete
        _starts = State(initialValue: defaultWindow.start)
        _ends = State(initialValue: defaultWindow.end)
    }

    private var routineID: UUID? {
        if case let .routine(id) = mode { return id }
        return nil
    }

    private var oneTimeID: UUID? {
        if case let .oneTime(id) = mode { return id }
        return nil
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $title)
                DatePicker("Starts", selection: $starts, displayedComponents: [.date, .hourAndMinute])
                DatePicker("Ends", selection: $ends, in: starts..., displayedComponents: [.date, .hourAndMinute])
            }

            if routineID != nil || isNewRoutine {
                Section("Repeats") {
                    Picker("Repeats", selection: recurrenceBinding) {
                        Text("Daily").tag(WindDownRecurrence.daily)
                        Text("Weekdays").tag(WindDownRecurrence.weekdays)
                        Text("Custom days").tag(WindDownRecurrence.custom(selectedWeekdays.sorted()))
                    }
                    if case .custom = recurrence {
                        weekdayPicker
                    }
                    Toggle("Enabled", isOn: $enabled)
                }
            } else if oneTimeID != nil || isNewOneTime {
                Section {
                    if isNewOneTime {
                        Button {
                            let practice = QuietPeriodScheduling.defaultWindow(
                                now: Date(),
                                preset: .startNowPractice
                            )
                            starts = practice.start
                            ends = practice.end
                        } label: {
                            Label("Start now", systemImage: "play.fill")
                        }
                    }
                    Toggle("Enabled", isOn: $enabled)
                }
            }

            if let error {
                Text(error).font(AppTypography.caption).foregroundStyle(AppColors.grass)
            }

            Section {
                Button(isNewOneTime ? "Save quiet time" : "Save changes") {
                    save()
                }
                .buttonStyle(.borderedProminent)

                if let oneTimeID {
                    Button("Cancel this quiet time", role: .destructive) {
                        viewModel.cancelOneTimeQuiet(id: oneTimeID)
                        dismiss()
                    }
                }
                if let routineID {
                    Button("Cancel this repeating time", role: .destructive) {
                        viewModel.cancelAdditionalRoutine(id: routineID)
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle(isNewOneTime || isNewRoutine ? "Add quiet time" : "Edit quiet time")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .onAppear(perform: load)
    }

    private var isNewOneTime: Bool {
        if case .oneTime(nil) = mode { return true }
        return false
    }

    private var isNewRoutine: Bool {
        if case .routine(nil) = mode { return true }
        return false
    }

    private var recurrenceBinding: Binding<WindDownRecurrence> {
        Binding(
            get: { recurrence },
            set: { selected in
                recurrence = selected
                if case let .custom(days) = selected { selectedWeekdays = Set(days) }
            }
        )
    }

    private var weekdayPicker: some View {
        let labels = Calendar.current.shortWeekdaySymbols
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7)) {
            ForEach(1...7, id: \.self) { day in
                Button(labels[day - 1]) {
                    if selectedWeekdays.contains(day) {
                        selectedWeekdays.remove(day)
                    } else {
                        selectedWeekdays.insert(day)
                    }
                    recurrence = .custom(selectedWeekdays.sorted())
                }
                .buttonStyle(.bordered)
                .tint(selectedWeekdays.contains(day) ? AppColors.grass : AppColors.muted)
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
            recurrence = routine.recurrence
            selectedWeekdays = Set(routine.weekdays)
            enabled = routine.enabled
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
        let selectedRecurrence: WindDownRecurrence = {
            if case .custom = recurrence { return .custom(selectedWeekdays.sorted()) }
            return recurrence
        }()
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

#Preview {
    NavigationStack {
        WindDownScheduleView()
            .environmentObject(FocusRunViewModel())
    }
}

#Preview("One-time editor · five-minute practice") {
    NavigationStack {
        QuietTimeEditorView(mode: .oneTime(nil), onComplete: { _ in })
            .environmentObject(FocusRunViewModel())
    }
    .preferredColorScheme(.dark)
}
