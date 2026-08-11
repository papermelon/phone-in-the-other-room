import SwiftUI

struct MonthlyNightsView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var month: Date

    private let calendar = Calendar.current

    init(month: Date = Date()) {
        _month = State(initialValue: Calendar.current.date(
            from: Calendar.current.dateComponents([.year, .month], from: month)
        ) ?? month)
    }

    private var monthSummary: NightsHistoryRange {
        NightsHistoryAggregator.monthSummary(
            from: viewModel.nightWatchRecords,
            containing: month,
            calendar: calendar
        )
    }

    private var summaryByDay: [Date: NightsHistoryDay] {
        Dictionary(uniqueKeysWithValues: monthSummary.days.map { (calendar.startOfDay(for: $0.day), $0) })
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

    private var canMoveToNextMonth: Bool {
        let currentMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: Date())
        ) ?? Date()
        return month < currentMonth
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
        .navigationTitle("All nights")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var monthHeader: some View {
        HStack(spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(month.formatted(.dateTime.month(.wide).year()))
                    .font(AppTypography.display(28))
                Text("Recorded quiet at a glance")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
            Spacer(minLength: 0)
            HStack(spacing: AppSpacing.xs) {
                monthButton(systemName: "chevron.left", label: "Previous month", isEnabled: true) {
                    shiftMonth(by: -1)
                }
                monthButton(systemName: "chevron.right", label: "Next month", isEnabled: canMoveToNextMonth) {
                    shiftMonth(by: 1)
                }
            }
        }
    }

    private var totalsCard: some View {
        PixelCard {
            HStack(spacing: 0) {
                totalMetric(value: "\(monthSummary.protectedNightCount)", label: "protected")
                Divider()
                    .frame(height: AppSpacing.xxl + AppSpacing.xs)
                    .padding(.horizontal, AppSpacing.sm)
                totalMetric(value: monthSummary.recordedQuietMinutes.formatted(), label: "recorded quiet")
                Divider()
                    .frame(height: AppSpacing.xxl + AppSpacing.xs)
                    .padding(.horizontal, AppSpacing.sm)
                totalMetric(
                    value: "\(monthSummary.totalOccurrenceCount)",
                    label: monthSummary.totalOccurrenceCount == 1 ? "period" : "periods"
                )
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(monthSummary.protectedNightCount) protected nights, \(monthSummary.recordedQuietMinutes) recorded quiet minutes, \(monthSummary.totalOccurrenceCount) periods")
        }
    }

    private var calendarCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("RECORDED DAYS")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                legend
                calendarLayout
            }
        }
    }

    private var legend: some View {
        HStack(spacing: AppSpacing.sm) {
            legendItem("Protected", systemImage: "shield.fill", color: AppColors.grass)
            legendItem("Ended early", systemImage: "moon.stars.fill", color: AppColors.warning)
            legendItem("One-time", systemImage: "sparkles", color: AppColors.lavender)
        }
    }

    @ViewBuilder
    private var calendarLayout: some View {
        if dynamicTypeSize.isAccessibilitySize {
            ScrollView(.horizontal, showsIndicators: false) {
                calendarGrid
                    .frame(width: AppSpacing.xxl * 12)
            }
            .accessibilityLabel("Calendar for \(month.formatted(.dateTime.month(.wide).year()))")
        } else {
            calendarGrid
        }
    }

    private var calendarGrid: some View {
        VStack(spacing: AppSpacing.sm) {
            weekdayHeader
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: AppSpacing.xs),
                    count: 7
                ),
                spacing: AppSpacing.sm
            ) {
                ForEach(0..<leadingEmptyDays, id: \.self) { _ in
                    Color.clear
                        .frame(height: AppSpacing.xxl + AppSpacing.lg)
                        .accessibilityHidden(true)
                }
                ForEach(daysInMonth, id: \.self) { day in
                    dayCell(day)
                }
            }
        }
    }

    private var weekdayHeader: some View {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let ordered = Array(symbols[(calendar.firstWeekday - 1)...])
            + Array(symbols[..<(calendar.firstWeekday - 1)])
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
                WindDownDayDetailView(
                    day: day,
                    records: NightsHistoryAggregator.records(
                        for: day,
                        from: viewModel.nightWatchRecords,
                        calendar: calendar
                    )
                )
            } label: {
                dayCellLabel(day: day, summary: summary)
            }
            .buttonStyle(.plain)
        } else {
            dayCellLabel(day: day, summary: nil)
        }
    }

    private func dayCellLabel(day: Date, summary: NightsHistoryDay?) -> some View {
        VStack(spacing: AppSpacing.xxs) {
            Text(day.formatted(.dateTime.day()))
                .font(AppTypography.headline)
                .foregroundStyle(summary == nil ? AppColors.muted : AppColors.ink)
            dayMarkers(summary)
                .frame(minHeight: AppSpacing.lg)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: AppSpacing.xxl + AppSpacing.lg)
        .background(cellBackground(summary), in: RoundedRectangle(cornerRadius: AppRadius.sm))
        .overlay(alignment: .topTrailing) {
            if let summary, summary.totalOccurrenceCount > 1 {
                Text("\(summary.totalOccurrenceCount)×")
                    .font(AppTypography.monoCaption)
                    .foregroundStyle(AppColors.ink)
                    .padding(AppSpacing.xxs)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(dayAccessibilityLabel(day: day, summary: summary))
        .accessibilityHint(summary == nil ? "No recorded quiet" : "Opens this day’s records")
    }

    private func dayMarkers(_ summary: NightsHistoryDay?) -> some View {
        HStack(spacing: AppSpacing.xxs) {
            if let summary {
                switch summary.primaryOutcome {
                case .protected:
                    Image(systemName: "shield.fill")
                        .foregroundStyle(AppColors.grass)
                    if summary.earlyEndedPrimaryCount > 0 {
                        Image(systemName: "moon.stars.fill")
                            .foregroundStyle(AppColors.warning)
                    }
                case .endedEarly:
                    Image(systemName: "moon.stars.fill")
                        .foregroundStyle(AppColors.warning)
                case nil:
                    if summary.additionalCount > 0 {
                        Image(systemName: "sparkles")
                            .foregroundStyle(AppColors.lavender)
                    }
                }
                if summary.additionalCount > 0, summary.primaryOutcome != nil {
                    Image(systemName: "sparkles")
                        .foregroundStyle(AppColors.lavender)
                }
            }
        }
        .font(AppTypography.monoCaption)
        .accessibilityHidden(true)
    }

    private var explanation: some View {
        Text("Tap a recorded day for its periods. Recorded quiet counts overlapping time once.")
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
                .minimumScaleFactor(0.7)
            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.muted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }

    private func legendItem(_ label: String, systemImage: String, color: Color) -> some View {
        Label(label, systemImage: systemImage)
            .font(AppTypography.monoCaption)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }

    private func cellBackground(_ summary: NightsHistoryDay?) -> Color {
        summary == nil ? Color.clear : AppColors.surfaceMuted.opacity(0.48)
    }

    private func monthButton(
        systemName: String,
        label: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(AppTypography.headline)
                .frame(
                    width: AppSpacing.xxl + AppSpacing.xs,
                    height: AppSpacing.xxl + AppSpacing.xs
                )
                .foregroundStyle(AppColors.ink)
                .background(AppColors.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityLabel(label)
    }

    private func shiftMonth(by value: Int) {
        withAnimation(AppMotion.navigation) {
            month = calendar.date(byAdding: .month, value: value, to: month) ?? month
        }
    }

    private func dayAccessibilityLabel(day: Date, summary: NightsHistoryDay?) -> String {
        let date = day.formatted(.dateTime.month(.wide).day())
        guard let summary else { return "\(date), no recorded quiet" }
        var parts = ["\(date), \(summary.totalOccurrenceCount) period\(summary.totalOccurrenceCount == 1 ? "" : "s")"]
        switch summary.primaryOutcome {
        case .protected:
            parts.append("protected night")
        case .endedEarly:
            parts.append("ended early")
        case nil:
            break
        }
        if summary.primaryOutcome == .protected, summary.earlyEndedPrimaryCount > 0 {
            parts.append("\(summary.earlyEndedPrimaryCount) other usual Wind Down attempt\(summary.earlyEndedPrimaryCount == 1 ? "" : "s") ended early")
        }
        if summary.additionalCount > 0 {
            parts.append("\(summary.additionalCount) one-time")
        }
        parts.append("\(summary.recordedQuietMinutes) recorded quiet minutes")
        return parts.joined(separator: ", ")
    }
}

#Preview("All nights · empty") {
    NavigationStack {
        MonthlyNightsView()
            .environmentObject(FocusRunViewModel())
    }
}

#Preview("All nights · accessibility · dark") {
    NavigationStack {
        MonthlyNightsView()
            .environmentObject(FocusRunViewModel())
    }
    .environment(\.dynamicTypeSize, .accessibility2)
    .preferredColorScheme(.dark)
}
