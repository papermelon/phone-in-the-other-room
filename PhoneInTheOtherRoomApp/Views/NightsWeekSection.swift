import SwiftUI

struct NightsSevenDaySection: View {
    @ObservedObject var viewModel: FocusRunViewModel
    var now = Date()

    private var summary: NightsHistoryRange {
        NightsHistoryAggregator.weekSummary(
            from: viewModel.nightWatchRecords,
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
                    Text("\(summary.protectedNightCount) of 7 protected · \(summary.recordedQuietMinutes) min recorded quiet")
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
        HStack(spacing: AppSpacing.sm) {
            legendItem("Protected", systemImage: "shield.fill", color: AppColors.grass)
            legendItem("Ended early", systemImage: "moon.stars.fill", color: AppColors.warning)
            legendItem("One-time", systemImage: "sparkles", color: AppColors.lavender)
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

            NightsMiniBookendRail(
                windDownMinutes: day.protectedWindDownMinutes,
                morningMinutes: day.protectedMorningQuietMinutes
            )
        }
        .padding(.horizontal, AppSpacing.xxs)
        .padding(.vertical, AppSpacing.xs)
        .frame(maxWidth: .infinity)
        .frame(minHeight: AppSpacing.xxl * 3)
        .background(AppColors.surfaceMuted.opacity(0.48), in: RoundedRectangle(cornerRadius: AppRadius.sm))
        .overlay(alignment: .topTrailing) {
            if day.additionalCount > 0, day.primaryOutcome != nil {
                Text("+\(day.additionalCount)")
                    .font(AppTypography.monoCaption)
                    .foregroundStyle(AppColors.lavender)
                    .padding(AppSpacing.xxs)
            }
        }
    }

    private var statusMarks: some View {
        HStack(spacing: AppSpacing.xxs) {
            switch day.primaryOutcome {
            case .protected:
                Image(systemName: "shield.fill")
                    .foregroundStyle(AppColors.grass)
                if day.earlyEndedPrimaryCount > 0 {
                    Image(systemName: "moon.stars.fill")
                        .font(AppTypography.monoCaption)
                        .foregroundStyle(AppColors.warning)
                }
            case .endedEarly:
                Image(systemName: "moon.stars.fill")
                    .foregroundStyle(AppColors.warning)
            case nil:
                if day.additionalCount > 0 {
                    Image(systemName: "sparkles")
                        .foregroundStyle(AppColors.lavender)
                } else {
                    Image(systemName: "minus")
                        .foregroundStyle(AppColors.muted)
                }
            }
        }
        .font(AppTypography.headline)
        .accessibilityHidden(true)
    }

    private var weekdayLabel: String {
        if showsFullWeekday {
            return day.day.formatted(.dateTime.weekday(.abbreviated))
        }
        return String(day.day.formatted(.dateTime.weekday(.narrow)).prefix(1))
    }

    private var valueLabel: String {
        switch day.primaryOutcome {
        case .protected: return "\(day.protectedQuietMinutes)m"
        case .endedEarly: return "Early"
        case nil:
            return day.additionalCount > 0 ? "\(day.additionalQuietMinutes)m" : "—"
        }
    }

    private var valueColor: Color {
        switch day.primaryOutcome {
        case .protected: return AppColors.grass
        case .endedEarly: return AppColors.warning
        case nil: return day.additionalCount > 0 ? AppColors.lavender : AppColors.muted
        }
    }

    private var accessibilityValue: String {
        guard day.hasRecords else { return "No recorded quiet" }
        var parts: [String] = []
        switch day.primaryOutcome {
        case .protected:
            parts.append("Protected night, \(day.protectedQuietMinutes) quiet minutes")
        case .endedEarly:
            parts.append("\(day.earlyEndedPrimaryCount) early-ended Wind Down\(day.earlyEndedPrimaryCount == 1 ? "" : "s")")
        case nil:
            break
        }
        if day.primaryOutcome == .protected, day.earlyEndedPrimaryCount > 0 {
            parts.append("\(day.earlyEndedPrimaryCount) other usual Wind Down attempt\(day.earlyEndedPrimaryCount == 1 ? "" : "s") ended early")
        }
        if day.additionalCount > 0 {
            parts.append("\(day.additionalCount) Phone Break\(day.additionalCount == 1 ? "" : "s"), \(day.additionalQuietMinutes) minutes")
        }
        return parts.joined(separator: ", ")
    }
}

private struct NightsMiniBookendRail: View {
    let windDownMinutes: Int
    let morningMinutes: Int

    private var total: Int {
        windDownMinutes + morningMinutes
    }

    var body: some View {
        GeometryReader { proxy in
            let availableWidth = proxy.size.width
            let windDownWidth = total > 0
                ? availableWidth * CGFloat(windDownMinutes) / CGFloat(total)
                : 0
            HStack(spacing: AppSpacing.xxs) {
                Capsule()
                    .fill(total > 0 ? AppColors.grass : AppColors.muted.opacity(0.25))
                    .frame(width: max(0, windDownWidth - AppSpacing.xxs / 2))
                Capsule()
                    .fill(total > 0 ? AppColors.grassLight : AppColors.muted.opacity(0.25))
            }
        }
        .frame(height: AppSpacing.xxs)
        .accessibilityHidden(true)
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
            return summary(day: day, outcome: .protected, primary: 1, windDown: 45, morning: 30)
        case 4:
            return summary(day: day, additional: 2, additionalMinutes: 29)
        case 5:
            return summary(day: day, outcome: .protected, primary: 1, windDown: 60, morning: 45, additional: 1, additionalMinutes: 15)
        default:
            return summary(day: day)
        }
    }
    static let summary = NightsHistoryRange(
        days: days,
        protectedNightCount: days.reduce(0) { $0 + $1.protectedNightCount },
        recordedQuietMinutes: days.reduce(0) { $0 + $1.recordedQuietMinutes },
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
            protectedNightCount: outcome == .protected ? 1 : 0,
            protectedWindDownMinutes: windDown,
            protectedMorningQuietMinutes: morning,
            primaryQuietMinutes: windDown + morning,
            earlyEndedPrimaryCount: early,
            additionalCount: additional,
            additionalQuietMinutes: additionalMinutes,
            recordedQuietMinutes: windDown + morning + additionalMinutes,
            primaryRecordIDs: [],
            additionalRecordIDs: []
        )
    }
}
