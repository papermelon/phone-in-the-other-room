import SwiftUI

struct PixelHomeDashboard: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @ObservedObject private var watch: WatchConnectivityManager
    @State private var showRunSetup = false

    init(watch: WatchConnectivityManager = .shared) {
        self._watch = ObservedObject(initialValue: watch)
    }

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            PixelHomeDashboardContent(
                progress: viewModel.coordinator.progress,
                preferences: viewModel.nightWatchPreferences,
                purpose: viewModel.offlinePurpose,
                watchReachable: watch.isReachable,
                canBeginNow: viewModel.canBeginNightWatchNow,
                onPrimaryAction: {
                    if viewModel.hasConfiguredNightWatch && viewModel.canBeginNightWatchNow {
                        viewModel.requestStartNightWatch()
                    } else {
                        showRunSetup = true
                    }
                },
                onAdjust: { showRunSetup = true }
            )

            PixelCard {
                QuietWindowDurationEditor()
                    .environmentObject(viewModel)
            }
        }
        .navigationDestination(isPresented: $showRunSetup) {
            FocusRunSetupView()
                .environmentObject(viewModel)
        }
    }
}

private struct PixelHomeDashboardContent: View {
    var progress: UserProgress
    var preferences: NightWatchPreferences
    var purpose: OfflinePurposeProfile
    var watchReachable: Bool
    var canBeginNow: Bool
    var onPrimaryAction: () -> Void
    var onAdjust: () -> Void

    private var latestNight: DailyFocusRecord? { progress.recentFocusRecords.first }

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            NightWatchOverviewBlock(preferences: preferences, latestNight: latestNight)

            OllieRitualView(state: .ready, size: 152)
                .accessibilityLabel("Ollie is ready for tonight's quiet time")

            VStack(spacing: AppSpacing.sm) {
                Text(purpose.inAppDisplayPhrase)
                    .font(AppTypography.headline)
                    .multilineTextAlignment(.center)
                Text("The quiet is the point. There is nothing to check off.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                    .multilineTextAlignment(.center)
            }

            PrimaryGreenCTA(
                title: primaryTitle,
                subtitle: preferences.isConfigured ? scheduleLabel : "Choose when your phone rests",
                icon: "door.left.hand.open",
                assetName: AssetSlot.Home.door,
                action: onPrimaryAction
            )

            if preferences.isConfigured {
                Button("Change bedtime, wake time, or purpose", action: onAdjust)
                    .buttonStyle(PixelChipButtonStyle(isSelected: false))
            }

            if preferences.guardKind == .watchPlacement {
                watchStatus
            }
        }
    }

    private var primaryTitle: String {
        if !preferences.isConfigured { return "Set Quiet Time" }
        return canBeginNow ? "Start Quiet Time" : "Adjust Quiet Time"
    }

    private var scheduleLabel: String {
        let bedtime = preferences.bedtimeDate().formatted(date: .omitted, time: .shortened)
        let phoneWakeDate = Calendar.current.date(
            byAdding: .minute,
            value: preferences.morningQuietMinutes,
            to: preferences.wakeDate()
        ) ?? preferences.wakeDate()
        let phoneWake = phoneWakeDate.formatted(date: .omitted, time: .shortened)
        return "Bed \(bedtime) · phone wakes \(phoneWake)"
    }

    private var watchStatus: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "applewatch")
                .foregroundStyle(AppColors.grass)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(watchReachable ? "Watch check is ready" : "Open the Watch app for placement")
                    .font(AppTypography.body)
                Text("The Watch is only used for the brief phone-bed check.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
            Spacer()
        }
        .padding(AppSpacing.md)
        .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.md))
    }
}

private struct NightWatchOverviewBlock: View {
    var preferences: NightWatchPreferences
    var latestNight: DailyFocusRecord?

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text("TONIGHT")
                            .font(pixelFont(.caption))
                            .foregroundStyle(AppColors.grass)
                        Text(preferences.isConfigured ? scheduleLabel : "Make a little room for quiet")
                            .font(pixelFont(.title3))
                    }
                    Spacer()
                    Image(systemName: "moon.stars.fill")
                        .font(.title2.weight(.black))
                        .foregroundStyle(AppColors.lavender)
                }

                HStack(spacing: AppSpacing.sm) {
                    quietPeriod(
                        icon: "moon.zzz.fill",
                        label: "Before bed",
                        minutes: preferences.windDownMinutes
                    )
                    quietPeriod(
                        icon: "sun.max.fill",
                        label: "After waking",
                        minutes: preferences.morningQuietMinutes
                    )
                }

                if let latestNight {
                    Text("Latest night · \(latestNight.completedFocusMinutes) phone-free minutes")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                } else {
                    Text("Your first protected night will appear in Nights.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
            }
        }
    }

    private var scheduleLabel: String {
        let bedtime = preferences.bedtimeDate().formatted(date: .omitted, time: .shortened)
        let wake = preferences.wakeDate().formatted(date: .omitted, time: .shortened)
        return "\(bedtime) – \(wake)"
    }

    private func quietPeriod(icon: String, label: String, minutes: Int) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(AppColors.grass)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(label)
                    .font(AppTypography.caption)
                Text("\(minutes) min")
                    .font(AppTypography.headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.sm)
        .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.md))
    }
}

#Preview("Quiet home") {
    NavigationStack {
        ScrollView {
            PixelHomeDashboardContent(
                progress: .empty,
                preferences: .defaults,
                purpose: OfflinePurposeProfile(category: .read),
                watchReachable: false,
                canBeginNow: false,
                onPrimaryAction: {},
                onAdjust: {}
            )
            .padding(AppSpacing.md)
        }
        .background(AppColors.paper)
    }
}

#Preview("Configured quiet home") {
    let preferences = NightWatchPreferences(
        bedtimeHour: 23,
        bedtimeMinute: 0,
        wakeHour: 7,
        wakeMinute: 0,
        windDownMinutes: 180,
        morningQuietMinutes: 180,
        eveningActivity: .read,
        morningActivity: .openCurtains,
        guardKind: .honorTimer,
        isConfigured: true
    )
    return NavigationStack {
        ScrollView {
            PixelHomeDashboardContent(
                progress: .empty,
                preferences: preferences,
                purpose: OfflinePurposeProfile(category: .read),
                watchReachable: false,
                canBeginNow: false,
                onPrimaryAction: {},
                onAdjust: {}
            )
            .padding(AppSpacing.md)
        }
        .background(AppColors.paper)
    }
}
