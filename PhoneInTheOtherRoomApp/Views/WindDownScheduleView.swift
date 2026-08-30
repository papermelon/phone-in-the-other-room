import SwiftUI

struct WindDownScheduleView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var editor: Editor?
    @State private var message: String?
    @State private var contextualTip: CountingSheepContextualTip?

    private var upcomingOneTimePeriods: [WindDownOneTimePeriod] {
        viewModel.windDownSchedule.oneTimePeriods
            .filter { $0.cancelledAt == nil && $0.interval.end > viewModel.currentDate }
            .sorted { $0.interval.start < $1.interval.start }
    }

    private var protectionStartPresentation: HomeProtectionStartPresentation {
        HomeProtectionStartPresentation.resolve(
            readiness: viewModel.shieldingReadiness,
            selectionSummary: viewModel.shieldingSelectionSummary
        )
    }

    var body: some View {
        List {
            Section {
                Text("Start one now, or save one for later. Phone Away stays separate from Wind Down.")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.muted)

                Button {
                    let started = viewModel.startNewOneTimeAdditionalQuietNow()
                    if !started {
                        message = viewModel.windDownScheduleError ?? "Phone Away could not be started just now."
                    }
                } label: {
                    Label(phoneAwayStartTitle, systemImage: phoneAwayStartIcon)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(PixelPrimaryButtonStyle())
                .contextualGuideTarget(.phoneBreak)
                if let message {
                    Text(message)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.warning)
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }

            Section("One-time Phone Away") {
                if upcomingOneTimePeriods.isEmpty {
                    Text("No one-time Phone Away periods are scheduled.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.muted)
                } else {
                    ForEach(upcomingOneTimePeriods) { period in
                        let isReady = viewModel.isPhoneAwayPeriodReady(period.id)
                        HStack(spacing: AppSpacing.sm) {
                            if isReady {
                                Button {
                                    if !viewModel.requestStartNightWatch(sourceID: period.id) {
                                        message = viewModel.nightWatchStartStatus.isEmpty
                                            ? "That quiet window has passed or is too short to start now."
                                            : viewModel.nightWatchStartStatus
                                    }
                                } label: {
                                    scheduleRow(
                                        title: period.userFacingTitle,
                                        detail: formatted(period.interval),
                                        status: scheduledStartStatus,
                                        enabled: period.enabled,
                                        trailingIcon: scheduledStartIcon
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(scheduledStartAccessibilityLabel(for: period))
                                .accessibilityHint(scheduledStartAccessibilityHint)
                            } else {
                                scheduleRow(
                                    title: period.userFacingTitle,
                                    detail: formatted(period.interval),
                                    enabled: period.enabled
                                )
                            }

                            Button("Edit") {
                                editor = .oneTime(period.id)
                            }
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.grass)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Cancel", role: .destructive) {
                                viewModel.cancelOneTimeQuiet(id: period.id)
                            }
                        }
                    }
                }
                Button { editor = .newOneTime } label: {
                    Label("Plan one-time Phone Away", systemImage: "plus")
                }
            }

            Section("Repeating Phone Away") {
                let routines = viewModel.windDownSchedule.routines.filter {
                    $0.role == .additionalQuiet
                }
                if routines.isEmpty {
                    Text("No repeating Phone Away periods yet.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.muted)
                } else {
                    ForEach(routines) { routine in
                        Button { editor = .routine(routine.id) } label: {
                            scheduleRow(
                                title: routine.userFacingTitle,
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
                    Label("Plan repeating Phone Away", systemImage: "repeat")
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
        .navigationTitle("Phone Away schedule")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.refreshScreenTimeState()
            contextualTip = viewModel.contextualTip(from: [.phoneBreak])
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            viewModel.refreshScreenTimeState()
        }
        .contextualGuideOverlay(
            tip: $contextualTip,
            onAcknowledge: viewModel.acknowledgeContextualTip,
            onSkipAll: viewModel.disableContextualTips
        )
        .sheet(item: $editor) { editor in
            NavigationStack {
                switch editor {
                case .newOneTime:
                    QuietTimeEditorView(mode: .oneTime(nil), onComplete: { success in
                        message = success ? "Ollie saved that Phone Away period." : "Choose a future window that does not overlap another Phone Away period."
                    })
                case let .oneTime(id):
                    QuietTimeEditorView(mode: .oneTime(id), onComplete: { success in
                        message = success ? "Ollie updated that Phone Away period." : "Choose a future window that does not overlap another Phone Away period."
                    })
                case .newRoutine:
                    QuietTimeEditorView(mode: .routine(nil), onComplete: { success in
                        message = success ? "Ollie saved that repeating Phone Away period." : "That repeat overlaps another Phone Away period. Choose a different window."
                    })
                case let .routine(id):
                    QuietTimeEditorView(mode: .routine(id), onComplete: { success in
                        message = success ? "Ollie updated that repeating Phone Away period." : "That repeat overlaps another Phone Away period. Choose a different window."
                    })
                }
            }
            .environmentObject(viewModel)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var phoneAwayStartTitle: String {
        if case let .repair(title, _) = protectionStartPresentation { return title }
        return "Start now"
    }

    private var phoneAwayStartIcon: String {
        viewModel.shieldingReadiness == .ready ? "timer" : "shield.lefthalf.filled"
    }

    private func scheduledStartAccessibilityLabel(for period: WindDownOneTimePeriod) -> String {
        if case let .repair(title, _) = protectionStartPresentation { return title }
        return "Start scheduled \(period.userFacingTitle)"
    }

    private var scheduledStartStatus: String {
        if case .repair = protectionStartPresentation {
            return "Available now · protection needed"
        }
        return "Ready now"
    }

    private var scheduledStartIcon: String {
        if case .repair = protectionStartPresentation { return "shield.lefthalf.filled" }
        return "play.fill"
    }

    private var scheduledStartAccessibilityHint: String {
        if case let .repair(_, detail) = protectionStartPresentation { return detail }
        return "Starts this scheduled Phone Away period"
    }

    private func scheduleRow(
        title: String,
        detail: String,
        status: String? = nil,
        enabled: Bool,
        trailingIcon: String = "chevron.right"
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
            Image(systemName: trailingIcon)
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
