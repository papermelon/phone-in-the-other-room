import SwiftUI

struct MonthlyNightsView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @State private var month: Date

    private let calendar = Calendar.current
    init(month: Date = Date()) {
        _month = State(initialValue: Calendar.current.date(
            from: Calendar.current.dateComponents([.year, .month], from: month)
        ) ?? month)
    }
    private var summaries: [WindDownDaySummary] {
        WindDownHistoryAggregator.monthSummaries(
            from: viewModel.nightWatchRecords,
            containing: month,
            calendar: calendar
        )
    }
    private var summaryByDay: [Date: WindDownDaySummary] {
        Dictionary(uniqueKeysWithValues: summaries.map { (calendar.startOfDay(for: $0.day), $0) })
    }

    private var monthInterval: DateInterval {
        calendar.dateInterval(of: .month, for: month)
            ?? DateInterval(start: month, duration: 31 * 24 * 60 * 60)
    }

    private var daysInMonth: [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        return range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start)
        }
    }

    private var leadingEmptyDays: Int {
        let weekday = calendar.component(.weekday, from: monthInterval.start)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private var quietMinutes: Int {
        summaries.reduce(0) { $0 + $1.quietMinutes }
    }

    private var protectedNights: Int {
        summaries.reduce(0) { $0 + $1.protectedNightCount }
    }

    private var completedOccurrences: Int {
        summaries.reduce(0) { $0 + $1.completedOccurrenceCount }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                monthHeader
                totalsCard
                calendarCard
                explanation
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Monthly nights")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var monthHeader: some View {
        HStack(spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(month.formatted(.dateTime.month(.wide).year()))
                    .font(AppTypography.display(28))
                Text("A month at a glance")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
            Spacer(minLength: 0)
            HStack(spacing: AppSpacing.xs) {
                monthButton(systemName: "chevron.left", label: "Previous month") {
                    shiftMonth(by: -1)
                }
                monthButton(systemName: "chevron.right", label: "Next month") {
                    shiftMonth(by: 1)
                }
            }
        }
    }

    private var totalsCard: some View {
        PixelCard {
            HStack(spacing: 0) {
                totalMetric(value: quietMinutesLabel, label: "quiet minutes")
                Divider()
                    .frame(height: 42)
                    .padding(.horizontal, AppSpacing.sm)
                totalMetric(value: "\(protectedNights)", label: protectedNights == 1 ? "protected night" : "protected nights")
                Divider()
                    .frame(height: 42)
                    .padding(.horizontal, AppSpacing.sm)
                totalMetric(value: "\(completedOccurrences)", label: completedOccurrences == 1 ? "Wind Down" : "Wind Downs")
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(quietMinutesLabel) quiet minutes, \(protectedNights) protected nights, \(completedOccurrences) completed Wind Downs")
        }
    }

    private var calendarCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack {
                    Text("RECORDED DAYS")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Spacer()
                    HStack(spacing: AppSpacing.xs) {
                        legendDot(color: AppColors.grass, label: "protected")
                        legendDot(color: AppColors.warning, label: "ended early")
                    }
                }

                weekdayHeader

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.xs), count: 7), spacing: AppSpacing.sm) {
                    ForEach(0..<leadingEmptyDays, id: \.self) { _ in
                        Color.clear
                            .frame(height: 42)
                            .accessibilityHidden(true)
                    }
                    ForEach(daysInMonth, id: \.self) { day in
                        dayCell(day)
                    }
                }
            }
        }
    }

    private var weekdayHeader: some View {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let ordered = Array(symbols[(calendar.firstWeekday - 1)...]) + Array(symbols[..<(calendar.firstWeekday - 1)])
        return HStack(spacing: 0) {
            ForEach(Array(ordered.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(AppTypography.monoCaption)
                    .foregroundStyle(AppColors.muted)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func dayCell(_ day: Date) -> some View {
        let key = calendar.startOfDay(for: day)
        if let summary = summaryByDay[key] {
            NavigationLink {
                WindDownDayDetailView(day: day, records: records(for: day))
            } label: {
                dayCellLabel(day: day, summary: summary)
            }
            .buttonStyle(.plain)
        } else {
            dayCellLabel(day: day, summary: nil)
        }
    }

    private func dayCellLabel(day: Date, summary: WindDownDaySummary?) -> some View {
        VStack(spacing: AppSpacing.xxs) {
            Text(day.formatted(.dateTime.day()))
                .font(AppTypography.headline)
                .foregroundStyle(summary == nil ? AppColors.muted : AppColors.ink)
            HStack(spacing: 3) {
                if let summary {
                    if summary.protectedNightCount > 0 {
                        Circle().fill(AppColors.grass).frame(width: 6, height: 6)
                    }
                    if summary.earlyEndedOccurrenceCount > 0 {
                        Circle().fill(AppColors.warning).frame(width: 6, height: 6)
                    }
                    if summary.occurrenceCount > 2 {
                        Text("+\(summary.occurrenceCount - 2)")
                            .font(AppTypography.monoCaption)
                            .foregroundStyle(AppColors.muted)
                    }
                } else {
                    Circle().fill(Color.clear).frame(width: 6, height: 6)
                }
            }
            .frame(height: 10)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 42)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(dayAccessibilityLabel(day: day, summary: summary))
        .accessibilityHint(summary == nil ? "No recorded Wind Down" : "Double tap to see this day's Wind Downs")
    }

    private var explanation: some View {
        Text("Tap a recorded day to see each Wind Down. Overlapping quiet periods are counted once, and one-time quiet periods stay separate from protected-night progress.")
            .font(AppTypography.caption)
            .foregroundStyle(AppColors.muted)
            .padding(.horizontal, AppSpacing.xs)
    }

    private func totalMetric(value: String, label: String) -> some View {
        VStack(spacing: AppSpacing.xxs) {
            Text(value)
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.grass)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.muted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(AppTypography.monoCaption)
                .foregroundStyle(AppColors.muted)
        }
        .accessibilityElement(children: .combine)
    }

    private func monthButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(AppTypography.headline)
                .frame(width: 34, height: 34)
                .foregroundStyle(AppColors.ink)
                .background(AppColors.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
        }
        .accessibilityLabel(label)
    }

    private func shiftMonth(by value: Int) {
        withAnimation(AppMotion.navigation) {
            month = calendar.date(byAdding: .month, value: value, to: month) ?? month
        }
    }

    private func records(for day: Date) -> [NightWatchRecord] {
        viewModel.nightWatchRecords
            .filter { record in
                record.outcome != .active
                    && calendar.isDate(record.plan.intendedBedtime, equalTo: day, toGranularity: .day)
            }
            .sorted { ($0.startedAt, $0.id) < ($1.startedAt, $1.id) }
    }

    private var quietMinutesLabel: String {
        quietMinutes.formatted()
    }

    private func dayAccessibilityLabel(day: Date, summary: WindDownDaySummary?) -> String {
        let date = day.formatted(.dateTime.month(.wide).day())
        guard let summary else { return date }
        return "\(date), \(summary.occurrenceCount) Wind Downs, \(summary.quietMinutes) quiet minutes"
    }
}

private struct WindDownDayDetailView: View {
    let day: Date
    let records: [NightWatchRecord]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text(day.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                    .font(AppTypography.display(28))
                if records.isEmpty {
                    PixelCard {
                        Text("No completed Wind Downs were recorded for this day.")
                            .font(AppTypography.body)
                    }
                } else {
                    ForEach(records) { record in
                        NavigationLink {
                            WindDownRecordDetailView(record: record)
                        } label: {
                            WindDownOccurrenceRow(record: record)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Wind Downs")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct WindDownOccurrenceRow: View {
    let record: NightWatchRecord

    var body: some View {
        PixelCard {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: record.occurrenceRole == .additionalQuiet ? "sparkles" : "moon.stars.fill")
                    .font(AppTypography.title)
                    .foregroundStyle(record.outcome == .completed ? AppColors.grass : AppColors.warning)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(record.occurrenceRole == .additionalQuiet ? "One-time quiet period" : "Wind Down")
                        .font(AppTypography.headline)
                    Text(intervalLabel)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                    Text(statusLabel)
                        .font(AppTypography.monoCaption)
                        .foregroundStyle(record.outcome == .completed ? AppColors.grass : AppColors.warning)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var intervalLabel: String {
        let intervals = record.creditedIntervals
        guard let first = intervals.first, let last = intervals.last else {
            return record.startedAt.formatted(date: .omitted, time: .shortened)
        }
        let end = last.end
        return "\(first.start.formatted(date: .omitted, time: .shortened))–\(end.formatted(date: .omitted, time: .shortened)) · \(quietMinutes) min"
    }

    private var quietMinutes: Int {
        record.creditedWindDownMinutes + record.creditedMorningQuietMinutes
    }

    private var statusLabel: String {
        record.outcome == .completed ? "Completed" : "Ended early"
    }
}

private struct WindDownRecordDetailView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    let record: NightWatchRecord

    private var searchOutcome: SheepSearchOutcome? {
        viewModel.sheepSearchState.outcomes.first { $0.runID == record.id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                PixelCard {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text(record.occurrenceRole == .additionalQuiet ? "One-time quiet period" : "Wind Down")
                            .font(AppTypography.display(26))
                        Text(record.outcome == .completed ? "Completed" : "Ended early")
                            .font(AppTypography.headline)
                            .foregroundStyle(record.outcome == .completed ? AppColors.grass : AppColors.warning)
                        Text("Started \(record.startedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.muted)
                    }
                }
                if let outcome = searchOutcome {
                    PixelCard {
                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            Text("OLLIE'S FIELD NOTE")
                                .font(pixelFont(.caption))
                                .foregroundStyle(AppColors.grass)
                            Text(outcome.sheepID.flatMap(SheepCatalog.definition).map { "Found \($0.name)" } ?? "Trail clue saved")
                                .font(AppTypography.headline)
                            if outcome.trailMapBonusPercentagePoints > 0 {
                                Text("+\(outcome.trailMapBonusPercentagePoints) mapped percentage points applied")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.muted)
                            }
                        }
                    }
                }
                PixelCard {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        detailMetric("Quiet before bed", value: "\(record.creditedWindDownMinutes) min")
                        detailMetric("Quiet after waking", value: "\(record.creditedMorningQuietMinutes) min")
                        detailMetric("Total quiet", value: "\(record.creditedWindDownMinutes + record.creditedMorningQuietMinutes) min")
                        if record.briefAccessUseCount > 0 {
                            detailMetric(
                                "Short breaks",
                                value: "\(record.briefAccessUseCount) short break\(record.briefAccessUseCount == 1 ? "" : "s")"
                            )
                        }
                    }
                }
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Wind Down")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detailMetric(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(AppTypography.body)
            Spacer(minLength: AppSpacing.sm)
            Text(value)
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.grass)
        }
    }
}

#Preview {
    NavigationStack {
        MonthlyNightsView()
            .environmentObject(FocusRunViewModel())
    }
}
