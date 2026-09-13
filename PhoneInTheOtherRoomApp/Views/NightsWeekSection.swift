import SwiftUI

struct NightsSevenDaySection: View {
    @ObservedObject var viewModel: FocusRunViewModel
    var now = Date()

    private var summary: NightsHistoryRange {
        NightsHistoryAggregator.weekSummary(
            from: viewModel.nightWatchRecords,
            morningOccurrences: viewModel.screenFreeMorningOccurrences,
            endingAt: now
        )
    }

    var body: some View {
        NightsWeekBoard(summary: summary, records: viewModel.nightWatchRecords)
    }
}

struct NightsWeekBoard: View {
    let summary: NightsHistoryRange
    let records: [NightWatchRecord]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Label("THIS WEEK", systemImage: "calendar")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text("\(summary.completedWindDownCount) of 7 Wind Downs · \(summary.windDownMinutes) min before bed")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                    Text("Screen-Free Morning \(summary.screenFreeMorningMinutes) min · Phone Away \(summary.phoneAwayMinutes) min")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }

                if dynamicTypeSize.isAccessibilitySize {
                    accessibilityDayCards
                } else {
                    compactDayCells
                }

                legend
            }
        }
    }

    private var compactDayCells: some View {
        HStack(alignment: .top, spacing: AppSpacing.xxs) {
            ForEach(summary.days) { day in
                NightsWeekDayCell(day: day, records: records)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var accessibilityDayCards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: AppSpacing.xs) {
                ForEach(summary.days) { day in
                    NightsWeekDayCell(
                        day: day,
                        records: records,
                        showsFullWeekday: true
                    )
                    .frame(width: AppSpacing.xxl * 3)
                }
            }
        }
        .accessibilityLabel("Last seven nights")
    }

    private var legend: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: AppSpacing.xxl * 3), alignment: .leading)],
            alignment: .leading,
            spacing: AppSpacing.xs
        ) {
            legendItem("Wind Down", systemImage: "checkmark.circle.fill", color: AppColors.grass)
            legendItem("Screen-Free Morning", systemImage: "sun.max.fill", color: AppColors.amber)
            legendItem("Ended early", systemImage: "moon.stars.fill", color: AppColors.warning)
            legendItem("Phone Away", systemImage: "sparkles", color: AppColors.lavender)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legendItem(_ label: String, systemImage: String, color: Color) -> some View {
        Label(label, systemImage: systemImage)
            .font(AppTypography.monoCaption)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }
}

private struct NightsWeekDayCell: View {
    let day: NightsHistoryDay
    let records: [NightWatchRecord]
    var showsFullWeekday = false

    var body: some View {
        Group {
            if day.hasRecords {
                NavigationLink {
                    WindDownDayDetailView(
                        day: day.day,
                        records: NightsHistoryAggregator.records(
                            for: day.day,
                            from: records
                        )
                    )
                } label: {
                    cellContent
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens this day’s records")
            } else {
                cellContent
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(day.day.formatted(.dateTime.weekday(.wide).month().day()))
        .accessibilityValue(accessibilityValue)
    }

    private var cellContent: some View {
        VStack(spacing: AppSpacing.xs) {
            VStack(spacing: AppSpacing.xxs) {
                Text(weekdayLabel)
                    .font(AppTypography.monoCaption)
                    .foregroundStyle(AppColors.muted)
                Text(day.day.formatted(.dateTime.day()))
                    .font(AppTypography.headline)
            }

            statusMarks
                .frame(minHeight: AppSpacing.xl)

            Text(valueLabel)
                .font(AppTypography.monoCaption)
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            NightsMiniSourceRail(
                windDownMinutes: day.windDownMinutes,
                morningMinutes: day.screenFreeMorningMinutes,
                phoneAwayMinutes: day.phoneAwayMinutes
            )
        }
        .padding(.horizontal, AppSpacing.xxs)
        .padding(.vertical, AppSpacing.xs)
        .frame(maxWidth: .infinity)
        .frame(minHeight: AppSpacing.xxl * 3)
        .background(AppColors.surfaceMuted.opacity(0.48), in: RoundedRectangle(cornerRadius: AppRadius.sm))
        .overlay(alignment: .topTrailing) {
            if day.totalOccurrenceCount > 1 {
                Text("\(day.totalOccurrenceCount)×")
                    .font(AppTypography.monoCaption)
                    .foregroundStyle(AppColors.muted)
                    .padding(AppSpacing.xxs)
            }
        }
    }

    private var statusMarks: some View {
        Image(systemName: statusSystemImage)
            .foregroundStyle(statusColor)
        .font(AppTypography.headline)
        .accessibilityHidden(true)
    }

    private var statusSystemImage: String {
        switch day.primaryOutcome {
        case .completed: return "checkmark.circle.fill"
        case .endedEarly: return "moon.stars.fill"
        case nil:
            if day.screenFreeMorningCount > 0 { return "sun.max.fill" }
            return day.additionalCount > 0 ? "sparkles" : "minus"
        }
    }

    private var statusColor: Color {
        switch day.primaryOutcome {
        case .completed: return AppColors.grass
        case .endedEarly: return AppColors.warning
        case nil:
            if day.screenFreeMorningCount > 0 { return AppColors.amber }
            return day.additionalCount > 0 ? AppColors.lavender : AppColors.muted
        }
    }

    private var weekdayLabel: String {
        if showsFullWeekday {
            return day.day.formatted(.dateTime.weekday(.abbreviated))
        }
        return String(day.day.formatted(.dateTime.weekday(.narrow)).prefix(1))
    }

    private var valueLabel: String {
        switch day.primaryOutcome {
        case .completed: return "\(day.windDownMinutes)m"
        case .endedEarly: return "Early"
        case nil:
            if day.screenFreeMorningCount > 0 { return "\(day.screenFreeMorningMinutes)m" }
            return day.additionalCount > 0 ? "\(day.phoneAwayMinutes)m" : "—"
        }
    }

    private var valueColor: Color {
        switch day.primaryOutcome {
        case .completed: return AppColors.grass
        case .endedEarly: return AppColors.warning
        case nil:
            if day.screenFreeMorningCount > 0 { return AppColors.amber }
            return day.additionalCount > 0 ? AppColors.lavender : AppColors.muted
        }
    }

    private var accessibilityValue: String {
        guard day.hasRecords else { return "No recorded quiet" }
        var parts: [String] = []
        switch day.primaryOutcome {
        case .completed:
            parts.append("Wind Down completed, \(day.windDownMinutes) minutes before bed")
        case .endedEarly:
            parts.append("\(day.earlyEndedPrimaryCount) early-ended Wind Down\(day.earlyEndedPrimaryCount == 1 ? "" : "s")")
        case nil:
            break
        }
        if day.primaryOutcome == .completed, day.earlyEndedPrimaryCount > 0 {
            parts.append("\(day.earlyEndedPrimaryCount) other usual Wind Down attempt\(day.earlyEndedPrimaryCount == 1 ? "" : "s") ended early")
        }
        if day.screenFreeMorningCount > 0 {
            parts.append("\(day.screenFreeMorningCount) Screen-Free Morning record\(day.screenFreeMorningCount == 1 ? "" : "s"), \(day.screenFreeMorningMinutes) eligible elapsed minutes")
        }
        if day.additionalCount > 0 {
            parts.append("\(day.additionalCount) Phone Away period\(day.additionalCount == 1 ? "" : "s"), \(day.phoneAwayMinutes) minutes")
        }
        if day.legacyMorningQuietMinutes > 0 {
            parts.append("earlier app record contains \(day.legacyMorningQuietMinutes) stored after-waking minutes kept separate")
        }
        return parts.joined(separator: ", ")
    }
}

private struct NightsMiniSourceRail: View {
    let windDownMinutes: Int
    let morningMinutes: Int
    let phoneAwayMinutes: Int

    var body: some View {
        HStack(spacing: AppSpacing.xxs) {
            sourceMark(color: AppColors.grass, isPresent: windDownMinutes > 0)
            sourceMark(color: AppColors.amber, isPresent: morningMinutes > 0)
            sourceMark(color: AppColors.lavender, isPresent: phoneAwayMinutes > 0)
        }
        .frame(height: AppSpacing.xxs)
        .accessibilityHidden(true)
    }

    private func sourceMark(color: Color, isPresent: Bool) -> some View {
        Capsule()
            .fill(isPresent ? color : AppColors.muted.opacity(0.2))
            .frame(maxWidth: .infinity)
    }
}

struct NightsMonthLink: View {
    @ObservedObject var viewModel: FocusRunViewModel

    var body: some View {
        NavigationLink {
            MonthlyNightsView()
                .environmentObject(viewModel)
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "calendar")
                    .foregroundStyle(AppColors.grass)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("View all nights")
                        .font(AppTypography.headline)
                    Text("Open the calendar and inspect any recorded day.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
                Spacer(minLength: AppSpacing.xs)
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppColors.muted)
                    .accessibilityHidden(true)
            }
            .padding(AppSpacing.md)
            .frame(minHeight: AppSpacing.xxl + AppSpacing.xl)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: AppRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(AppColors.stroke.opacity(0.14), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the complete night history")
    }
}

#Preview("This week · mixed states") {
    NavigationStack {
        NightsWeekBoard(summary: NightsWeekPreviewData.summary, records: [])
            .padding()
            .background(AppColors.paper)
    }
}

#Preview("This week · accessibility size · dark") {
    NavigationStack {
        NightsWeekBoard(summary: NightsWeekPreviewData.summary, records: [])
            .padding()
            .background(AppColors.paper)
    }
    .environment(\.dynamicTypeSize, .accessibility2)
    .preferredColorScheme(.dark)
}

private enum NightsWeekPreviewData {
    static let start = Calendar.current.startOfDay(for: Date()).addingTimeInterval(-6 * 86_400)
    static let days: [NightsHistoryDay] = (0..<7).map { offset in
        let day = Calendar.current.date(byAdding: .day, value: offset, to: start) ?? start
        switch offset {
        case 1:
            return summary(day: day, outcome: .endedEarly, primary: 1, early: 1)
        case 2:
            return summary(day: day, outcome: .completed, primary: 1, windDown: 45, morning: 30)
        case 4:
            return summary(day: day, additional: 2, additionalMinutes: 29)
        case 5:
            return summary(day: day, outcome: .completed, primary: 1, windDown: 60, morning: 45, additional: 1, additionalMinutes: 15)
        default:
            return summary(day: day)
        }
    }
    static let summary = NightsHistoryRange(
        days: days,
        completedWindDownCount: days.reduce(0) { $0 + $1.completedWindDownCount },
        windDownMinutes: days.reduce(0) { $0 + $1.windDownMinutes },
        screenFreeMorningCount: days.reduce(0) { $0 + $1.screenFreeMorningCount },
        completedScreenFreeMorningCount: days.reduce(0) { $0 + $1.completedScreenFreeMorningCount },
        screenFreeMorningMinutes: days.reduce(0) { $0 + $1.screenFreeMorningMinutes },
        phoneAwayMinutes: days.reduce(0) { $0 + $1.phoneAwayMinutes },
        legacyMorningQuietMinutes: days.reduce(0) { $0 + $1.legacyMorningQuietMinutes },
        totalOccurrenceCount: days.reduce(0) { $0 + $1.totalOccurrenceCount }
    )

    private static func summary(
        day: Date,
        outcome: NightsPrimaryOutcome? = nil,
        primary: Int = 0,
        windDown: Int = 0,
        morning: Int = 0,
        early: Int = 0,
        additional: Int = 0,
        additionalMinutes: Int = 0
    ) -> NightsHistoryDay {
        NightsHistoryDay(
            day: day,
            primaryOutcome: outcome,
            primaryAttemptCount: primary,
            completedWindDownCount: outcome == .completed ? 1 : 0,
            windDownMinutes: windDown,
            earlyEndedPrimaryCount: early,
            screenFreeMorningCount: morning > 0 ? 1 : 0,
            completedScreenFreeMorningCount: morning > 0 ? 1 : 0,
            skippedScreenFreeMorningCount: 0,
            screenFreeMorningMinutes: morning,
            legacyMorningQuietMinutes: 0,
            legacyMorningRecordCount: 0,
            additionalCount: additional,
            phoneAwayMinutes: additionalMinutes,
            primaryRecordIDs: [],
            screenFreeMorningOccurrenceIDs: [],
            additionalRecordIDs: []
        )
    }
}
