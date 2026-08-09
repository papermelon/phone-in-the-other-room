import SwiftUI

struct NightsHealthContext: View {
    @ObservedObject var viewModel: FocusRunViewModel
    @State private var isExpanded = false

    var body: some View {
        PixelCard {
            DisclosureGroup(isExpanded: $isExpanded) {
                healthDetails
                    .padding(.top, AppSpacing.sm)
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "heart.text.square.fill")
                        .foregroundStyle(AppColors.grass)
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text("Apple Health context")
                            .font(AppTypography.headline)
                        Text(summary)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.muted)
                    }
                }
            }
            .tint(AppColors.grass)
        }
    }

    private var summary: String {
        switch viewModel.sleepAuthorization {
        case .unavailable: return "Unavailable on this iPhone"
        case .notRequested: return "Optional · not connected"
        case .error: return "Could not load sleep context"
        case .requested:
            if viewModel.isRefreshingSleep { return "Checking Apple Health…" }
            if let sleep = viewModel.lastNightSleep {
                return "Sleep recorded for \(nightEndingLabel(for: sleep))"
            }
            if let olderSleep = viewModel.recentNightSleeps.first {
                return "Latest available sample: \(nightEndingLabel(for: olderSleep))"
            }
            return "No matching sleep sample yet"
        }
    }

    @ViewBuilder
    private var healthDetails: some View {
        switch viewModel.sleepAuthorization {
        case .unavailable:
            Text("Apple Health sleep data is unavailable on this device.")
                .font(AppTypography.body)
        case .notRequested:
            Text("Connect Apple Health in Settings when you want sleep duration and available stage context beside your nights.")
                .font(AppTypography.body)
        case .error:
            Text("Apple Health could not complete the request. You can try again from the Health app or Settings.")
                .font(AppTypography.body)
        case .requested:
            if viewModel.isRefreshingSleep {
                HStack(spacing: AppSpacing.sm) {
                    ProgressView()
                        .tint(AppColors.grass)
                    Text("Checking Apple Health…")
                        .font(AppTypography.body)
                }
            } else if let sleep = viewModel.lastNightSleep {
                sleepDetails(sleep, isStale: false)
            } else if let olderSleep = viewModel.recentNightSleeps.first {
                sleepDetails(olderSleep, isStale: true)
            } else {
                Text("No sleep sample was found for the latest night. Health context will appear when Apple has a matching sample.")
                    .font(AppTypography.body)
            }
        }
    }

    private func sleepDetails(_ sleep: SleepSummary, isStale: Bool) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(isStale ? "Latest available sample" : "Latest matching sample")
                .font(AppTypography.caption.weight(.semibold))
                .foregroundStyle(AppColors.muted)
            Text(sleep.durationLabel)
                .font(AppTypography.display(30))
            Text(nightEndingLabel(for: sleep))
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.grass)
            if let start = sleep.startDate, let end = sleep.endDate {
                Text("\(start.formatted(date: .omitted, time: .shortened))–\(end.formatted(date: .omitted, time: .shortened))")
                    .font(AppTypography.body)
            }
            if sleep.stages.hasStages {
                HStack(spacing: AppSpacing.sm) {
                    stageMetric("Core", seconds: sleep.stages.coreSeconds)
                    stageMetric("Deep", seconds: sleep.stages.deepSeconds)
                    stageMetric("REM", seconds: sleep.stages.remSeconds)
                }
            } else {
                Text("Apple Health did not provide separate Core, Deep, or REM stages for this sample.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
            if let wakeRange = SleepIntervalMath.wakeTimeRange(for: viewModel.recentNightSleeps) {
                Text("Wake-time range over \(wakeRange.sampleCount) available nights: \(wakeRangeLabel(wakeRange)). This is context, not a grade.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
        }
    }

    private func stageMetric(_ title: String, seconds: TimeInterval) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.muted)
            Text(durationLabel(seconds))
                .font(AppTypography.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func nightEndingLabel(for sleep: SleepSummary) -> String {
        let date = sleep.nightEndingDate ?? sleep.endDate ?? Date()
        return "Night ending \(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))"
    }

    private func durationLabel(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int(seconds / 60))
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }

    private func wakeRangeLabel(_ range: WakeTimeRange) -> String {
        range.minutes >= 60 ? "\(range.minutes / 60)h \(range.minutes % 60)m" : "\(range.minutes)m"
    }
}

struct NightsScreenTimeContext: View {
    @ObservedObject var viewModel: FocusRunViewModel

    var body: some View {
        switch viewModel.screenTimeAuthorization {
        case .unavailable:
            statusCard(
                title: "Screen Time context",
                detail: "Unavailable on this iPhone. Counting Sheep keeps working without it."
            )
        case .notDetermined:
            statusCard(
                title: "Screen Time context",
                detail: "Optional · connect Screen Time in Settings to compare one chosen evening or morning window at a time."
            )
        case .denied:
            statusCard(
                title: "Screen Time context",
                detail: "Access is off. Counting Sheep keeps working without it; permission can be changed later in Settings."
            )
        case .approved:
#if SCREEN_TIME_REPORTS && canImport(DeviceActivity) && canImport(FamilyControls)
            ScreenTimeBookendCard(showAppPicker: .constant(false), mode: .reports)
                .environmentObject(viewModel)
#else
            statusCard(
                title: "Screen Time context",
                detail: "Screen Time is connected, but its report extension is unavailable in this build."
            )
#endif
        }
    }

    private func statusCard(title: String, detail: String) -> some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Label(title, systemImage: "iphone.slash")
                    .font(AppTypography.headline)
                Text(detail)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.muted)
            }
        }
    }
}
