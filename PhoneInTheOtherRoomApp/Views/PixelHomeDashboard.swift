import SwiftUI

struct PixelHomeDashboard: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @ObservedObject private var watch: WatchConnectivityManager
    @State private var showRunSetup = false
    @State private var showTimingEditor = false
    @State private var showOneTimeWindDown = false

    init(watch: WatchConnectivityManager = .shared) {
        self._watch = ObservedObject(initialValue: watch)
    }

    var body: some View {
        PixelHomeDashboardContent(
            progress: viewModel.coordinator.progress,
            preferences: viewModel.nightWatchPreferences,
            purpose: viewModel.offlinePurpose,
            watchReachable: watch.isReachable,
            canBeginNow: viewModel.canBeginNightWatchNow,
            isNFCTagReady: viewModel.hasRegisteredNFCTag,
            hasOneTimeWindDown: viewModel.nextWindDownOverride?.role == .additionalQuiet,
            onPrimaryAction: {
                let methodIsReady = viewModel.selectedGuardKind != .nfcTag
                    || viewModel.hasRegisteredNFCTag
                if viewModel.hasConfiguredNightWatch
                    && viewModel.canBeginNightWatchNow
                    && methodIsReady {
                    viewModel.requestStartNightWatch()
                } else {
                    showRunSetup = true
                }
            },
            onEditTiming: { showTimingEditor = true },
            onOneTimeWindDown: { showOneTimeWindDown = true }
        )
        .navigationDestination(isPresented: $showRunSetup) {
            FocusRunSetupView()
                .environmentObject(viewModel)
        }
        .navigationDestination(isPresented: $showTimingEditor) {
            WindDownTimingView()
                .environmentObject(viewModel)
        }
        .navigationDestination(isPresented: $showOneTimeWindDown) {
            OneTimeWindDownView()
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
    var isNFCTagReady: Bool
    var hasOneTimeWindDown: Bool
    var onPrimaryAction: () -> Void
    var onEditTiming: () -> Void
    var onOneTimeWindDown: () -> Void

    private var latestNight: DailyFocusRecord? { progress.recentFocusRecords.first }

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            NightWatchOverviewBlock(
                preferences: preferences,
                latestNight: latestNight,
                onEdit: onEditTiming
            )

            OllieRitualView(state: .ready, size: 152)
                .accessibilityLabel("Ollie is ready for tonight's Wind Down")

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

            OneTimeWindDownCard(
                hasScheduledOverride: hasOneTimeWindDown,
                action: onOneTimeWindDown
            )

            if preferences.guardKind == .watchPlacement {
                watchStatus
            }
        }
    }

    private var primaryTitle: String {
        if !preferences.isConfigured { return "Set Wind Down" }
        if preferences.guardKind == .nfcTag, !isNFCTagReady {
            return "Set up NFC tag"
        }
        return canBeginNow ? "Start Wind Down" : "Adjust Wind Down"
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
                Text("The Watch is only used for one brief Wind Down check.")
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
    var onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
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
        .buttonStyle(.plain)
        .accessibilityHint("Opens your Wind Down and sleep window")
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

private struct OneTimeWindDownCard: View {
    var hasScheduledOverride: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            PixelCard {
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: "sparkles")
                        .font(.title2.weight(.black))
                        .foregroundStyle(AppColors.grass)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text("One-Time Wind Down")
                            .font(AppTypography.headline)
                        Text(hasScheduledOverride ? "A quiet period is ready for today." : "Make room for quiet at another point in the day.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.muted)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .foregroundStyle(AppColors.muted)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens a one-time additional quiet period")
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
                isNFCTagReady: false,
                hasOneTimeWindDown: false,
                onPrimaryAction: {},
                onEditTiming: {},
                onOneTimeWindDown: {}
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
    NavigationStack {
        ScrollView {
            PixelHomeDashboardContent(
                progress: .empty,
                preferences: preferences,
                purpose: OfflinePurposeProfile(category: .read),
                watchReachable: false,
                canBeginNow: false,
                isNFCTagReady: false,
                hasOneTimeWindDown: false,
                onPrimaryAction: {},
                onEditTiming: {},
                onOneTimeWindDown: {}
            )
            .padding(AppSpacing.md)
        }
        .background(AppColors.paper)
    }
}
