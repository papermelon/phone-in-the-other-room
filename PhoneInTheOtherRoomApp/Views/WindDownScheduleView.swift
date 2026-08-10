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

    private func scheduleRow(title: String, detail: String, status: String? = nil, enabled: Bool) -> some View {
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

#Preview {
    NavigationStack {
        WindDownScheduleView()
            .environmentObject(FocusRunViewModel())
    }
}
