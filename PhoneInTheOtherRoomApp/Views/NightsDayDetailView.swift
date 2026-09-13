import SwiftUI

struct WindDownDayDetailView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    let day: Date
    let records: [NightWatchRecord]
    @State private var showsPrimaryRecords = false
    @State private var showsAdditionalRecords = false

    private var summary: NightsHistoryDay {
        NightsHistoryAggregator.summary(
            for: day,
            from: records,
            morningOccurrences: screenFreeMorningOccurrences
        )
    }

    private var primaryRecords: [NightWatchRecord] {
        records.filter { $0.occurrenceRole.isProgressionEligible }
    }

    private var additionalRecords: [NightWatchRecord] {
        records.filter { $0.occurrenceRole == .additionalQuiet }
    }

    private var screenFreeMorningOccurrences: [MorningQuietOccurrence] {
        NightsHistoryAggregator.morningOccurrences(
            for: day,
            from: viewModel.screenFreeMorningOccurrences
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text(day.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                    .font(AppTypography.display(28))

                daySummary

                WindDownHabitReflectionCard(day: day)
                WindDownHabitReflectionCard(day: day, mode: .morning)

                if !summary.hasRecords {
                    PixelCard {
                        Text("No completed quiet periods were recorded for this day.")
                            .font(AppTypography.body)
                    }
                } else {
                    occurrenceGroup(
                        title: "WIND DOWN",
                        records: primaryRecords,
                        totalMinutes: summary.windDownMinutes,
                        accent: AppColors.grass,
                        isExpanded: $showsPrimaryRecords
                    )
                    screenFreeMorningGroup
                    legacyMorningCreditCard
                    occurrenceGroup(
                        title: "PHONE AWAY",
                        records: additionalRecords,
                        totalMinutes: summary.phoneAwayMinutes,
                        accent: AppColors.lavender,
                        isExpanded: $showsAdditionalRecords
                    )
                }
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Day record")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var screenFreeMorningGroup: some View {
        if !screenFreeMorningOccurrences.isEmpty {
            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("SCREEN-FREE MORNING")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.amber)
                    ForEach(screenFreeMorningOccurrences) { occurrence in
                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            HStack {
                                Text(occurrence.scheduledStart.formatted(date: .omitted, time: .shortened))
                                    .font(AppTypography.headline)
                                Spacer()
                                Text(morningStatus(occurrence))
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.secondaryText)
                            }
                            Text(morningDetail(occurrence))
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.muted)
                        }
                        if occurrence.id != screenFreeMorningOccurrences.last?.id { Divider() }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var legacyMorningCreditCard: some View {
        if summary.legacyMorningQuietMinutes > 0 {
            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("EARLIER APP RECORD")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.muted)
                    Text("\(summary.legacyMorningQuietMinutes) min after waking")
                        .font(AppTypography.headline)
                    Text("An earlier Counting Sheep version stored these minutes with Wind Down. They stay separate from Screen-Free Morning. No Morning details are inferred from this value.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
            }
        }
    }

    private func morningStatus(_ occurrence: MorningQuietOccurrence) -> String {
        switch occurrence.outcome {
        case .scheduled: return "Planned"
        case .active: return "In progress"
        case .skipped: return "Skipped"
        case .finished: return "Timer ended"
        }
    }

    private func morningDetail(_ occurrence: MorningQuietOccurrence) -> String {
        let minutes = occurrence.eligibleElapsedMinutes(at: occurrence.endedAt ?? Date())
        if occurrence.outcome == .skipped {
            return "No Screen-Free Morning minutes were recorded."
        }
        if occurrence.outcome == .finished, minutes < SunriseTrailRules.minimumOccurrenceMinutes {
            return "\(minutes) eligible elapsed minutes · below the 15-minute Screen-Free Morning minimum"
        }
        return "\(minutes) eligible elapsed minutes · recorded independently from Wind Down"
    }

    private var daySummary: some View {
        PixelCard {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Image(systemName: summarySystemImage)
                    .font(AppTypography.title)
                    .foregroundStyle(summaryColor)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(summaryTitle)
                        .font(AppTypography.headline)
                    Text(summaryDetail)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private func occurrenceGroup(
        title: String,
        records: [NightWatchRecord],
        totalMinutes: Int,
        accent: Color,
        isExpanded: Binding<Bool>
    ) -> some View {
        if !records.isEmpty {
            PixelCard {
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(pixelFont(.caption))
                        .foregroundStyle(accent)
                        .padding(.bottom, AppSpacing.xs)

                    if records.count > 2 {
                        DisclosureGroup(isExpanded: isExpanded) {
                            occurrenceRows(records)
                                .padding(.top, AppSpacing.xs)
                        } label: {
                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: groupSystemImage(records))
                                    .foregroundStyle(accent)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                    Text(groupSummary(records: records, totalMinutes: totalMinutes))
                                        .font(AppTypography.headline)
                                    Text("Show each recorded period")
                                        .font(AppTypography.caption)
                                        .foregroundStyle(AppColors.muted)
                                }
                            }
                            .frame(minHeight: AppSpacing.xxl + AppSpacing.xs)
                        }
                        .tint(accent)
                    } else {
                        occurrenceRows(records)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func occurrenceRows(_ records: [NightWatchRecord]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                if index > 0 { Divider() }
                NavigationLink {
                    WindDownRecordDetailView(record: record)
                } label: {
                    WindDownOccurrenceRow(record: record)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func groupSystemImage(_ records: [NightWatchRecord]) -> String {
        if records.first?.occurrenceRole == .additionalQuiet { return "sparkles" }
        return records.contains { $0.outcome == .completed }
            ? "checkmark.circle.fill"
            : "moon.stars.fill"
    }

    private func groupSummary(records: [NightWatchRecord], totalMinutes: Int) -> String {
        if records.first?.occurrenceRole == .additionalQuiet {
            return "\(records.count) periods · \(totalMinutes) min"
        }
        return "\(records.count) attempts · \(totalMinutes) min before bed"
    }

    private var summaryTitle: String {
        let sourceCount = (summary.primaryAttemptCount > 0 ? 1 : 0)
            + (summary.screenFreeMorningCount > 0 ? 1 : 0)
            + (summary.additionalCount > 0 ? 1 : 0)
        if sourceCount > 1 { return "Day record" }
        switch summary.primaryOutcome {
        case .completed: return "Wind Down completed"
        case .endedEarly: return "Ended early"
        case nil:
            if summary.screenFreeMorningCount > 0 { return "Screen-Free Morning" }
            return summary.additionalCount > 0 ? "Phone Away" : "No recorded quiet"
        }
    }

    private var summaryDetail: String {
        var parts: [String] = []
        if summary.primaryAttemptCount > 0 {
            let status = summary.primaryOutcome == .completed ? "completed" : "ended early"
            parts.append("Wind Down: \(summary.windDownMinutes) min before bed, \(status)")
        }
        if summary.primaryOutcome == .completed, summary.earlyEndedPrimaryCount > 0 {
            parts.append("\(summary.earlyEndedPrimaryCount) other Wind Down attempt\(summary.earlyEndedPrimaryCount == 1 ? "" : "s") ended early")
        }
        if summary.screenFreeMorningCount > 0 {
            parts.append("Screen-Free Morning: \(summary.screenFreeMorningMinutes) eligible elapsed min")
        }
        if summary.additionalCount > 0 {
            parts.append("Phone Away: \(summary.phoneAwayMinutes) min")
        }
        if summary.legacyMorningQuietMinutes > 0 {
            parts.append("Earlier record: \(summary.legacyMorningQuietMinutes) after-waking min kept separate")
        }
        return parts.joined(separator: " · ")
    }

    private var summarySystemImage: String {
        switch summary.primaryOutcome {
        case .completed: return "checkmark.circle.fill"
        case .endedEarly: return "moon.stars.fill"
        case nil:
            if summary.screenFreeMorningCount > 0 { return "sun.max.fill" }
            return summary.additionalCount > 0 ? "sparkles" : "minus"
        }
    }

    private var summaryColor: Color {
        switch summary.primaryOutcome {
        case .completed: return AppColors.grass
        case .endedEarly: return AppColors.warning
        case nil:
            if summary.screenFreeMorningCount > 0 { return AppColors.amber }
            return summary.additionalCount > 0 ? AppColors.lavender : AppColors.muted
        }
    }
}

struct WindDownOccurrenceRow: View {
    let record: NightWatchRecord

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: statusSystemImage)
                .font(AppTypography.headline)
                .foregroundStyle(statusColor)
                .frame(width: AppSpacing.xl)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(intervalLabel)
                    .font(AppTypography.body)
                Text(statusLabel)
                    .font(AppTypography.monoCaption)
                    .foregroundStyle(statusColor)
            }
            Spacer(minLength: AppSpacing.xs)
            Image(systemName: "chevron.right")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.muted)
                .accessibilityHidden(true)
        }
        .padding(.vertical, AppSpacing.sm)
        .frame(minHeight: AppSpacing.xxl + AppSpacing.sm)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens this record")
    }

    private var intervalLabel: String {
        if record.occurrenceRole == .additionalQuiet {
            let intervals = record.creditedIntervals
            if let first = intervals.first, let last = intervals.last {
                return "\(OllieFormat.timeRange(from: first.start, to: last.end)) · \(quietMinutes) min"
            }
        } else if let interval = windDownInterval {
            return "\(OllieFormat.timeRange(from: interval.start, to: interval.end)) · \(quietMinutes) min before bed"
        } else if quietMinutes == 0, record.startedAt >= record.plan.intendedBedtime {
            // Truthful zero: the Wind Down began at or after bedtime, so no
            // before-bed minutes exist. "0 min before bed" beside "Completed"
            // read as a broken record.
            return "\(OllieFormat.time(record.startedAt)) · 0 before-bed min recorded"
        } else {
            return "\(OllieFormat.time(record.startedAt)) · \(quietMinutes) min before bed"
        }
        let end = record.endedAt ?? record.updatedAt
        guard end > record.startedAt else { return OllieFormat.time(record.startedAt) }
        return OllieFormat.timeRange(from: record.startedAt, to: end)
    }

    private var quietMinutes: Int {
        record.occurrenceRole == .additionalQuiet
            ? record.creditedWindDownMinutes + record.creditedMorningQuietMinutes
            : record.creditedWindDownMinutes
    }

    private var windDownInterval: DateInterval? {
        guard record.creditedWindDownMinutes > 0 else { return nil }
        let plannedStart = record.plan.intendedBedtime.addingTimeInterval(
            TimeInterval(-record.plan.windDownMinutes * 60)
        )
        let start = max(record.startedAt, plannedStart)
        let availableEnd = min(record.endedAt ?? record.updatedAt, record.plan.intendedBedtime)
        let end = min(
            availableEnd,
            start.addingTimeInterval(TimeInterval(record.creditedWindDownMinutes * 60))
        )
        guard end > start else { return nil }
        return DateInterval(start: start, end: end)
    }

    private var statusLabel: String {
        record.outcome == .completed ? "Completed" : "Ended early"
    }

    private var statusColor: Color {
        if record.outcome == .endedEarly { return AppColors.warning }
        return record.occurrenceRole == .additionalQuiet ? AppColors.lavender : AppColors.grass
    }

    private var statusSystemImage: String {
        if record.outcome == .endedEarly { return "moon.stars.fill" }
        return record.occurrenceRole == .additionalQuiet ? "sparkles" : "checkmark.circle.fill"
    }
}

struct WindDownRecordDetailView: View {
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
                            Text(record.occurrenceRole == .additionalQuiet ? "Phone Away" : "Wind Down")
                            .font(AppTypography.display(26))
                        Text(record.outcome == .completed ? "Completed" : "Ended early")
                            .font(AppTypography.headline)
                            .foregroundStyle(record.outcome == .completed ? AppColors.grass : AppColors.warning)
                        Text("Started \(OllieFormat.dateAndTime(record.startedAt))")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.muted)
                    }
                }
                if let outcome = searchOutcome {
                    PixelCard {
                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            Text("SEARCH JOURNAL NOTE")
                                .font(pixelFont(.caption))
                                .foregroundStyle(AppColors.grass)
                            Text(SheepSearchPresentation.journalResultHeadline(for: outcome))
                                .font(AppTypography.headline)
                            Text(SheepSearchPresentation.openedByLine(for: outcome.origin))
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.muted)
                        }
                    }
                }
                PixelCard {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        if record.occurrenceRole == .additionalQuiet {
                            detailMetric("Phone-away time", value: "\(record.creditedWindDownMinutes + record.creditedMorningQuietMinutes) min")
                        } else {
                            detailMetric("Quiet before bed", value: "\(record.creditedWindDownMinutes) min")
                            if record.creditedMorningQuietMinutes > 0 {
                                Divider()
                                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                    detailMetric(
                                        "Earlier after-waking record",
                                        value: "\(record.creditedMorningQuietMinutes) min"
                                    )
                                    Text("An earlier app version stored this value with Wind Down. It stays separate from Screen-Free Morning. No Morning details are inferred from it.")
                                        .font(AppTypography.caption)
                                        .foregroundStyle(AppColors.muted)
                                }
                            }
                        }
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
        .navigationTitle(record.occurrenceRole == .additionalQuiet ? "Phone Away" : "Wind Down")
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

#Preview("Day record · busy") {
    NavigationStack {
        WindDownDayDetailView(
            day: NightsDayPreviewData.day,
            records: NightsDayPreviewData.records
        )
        .environmentObject(FocusRunViewModel())
    }
}

#Preview("Day record · empty · dark") {
    NavigationStack {
        WindDownDayDetailView(day: Date(), records: [])
            .environmentObject(FocusRunViewModel())
    }
    .preferredColorScheme(.dark)
}

private enum NightsDayPreviewData {
    static let day = Date()
    static let start = Calendar.current.startOfDay(for: day).addingTimeInterval(8 * 60 * 60)
    static let records: [NightWatchRecord] = (0..<4).map { offset in
        let periodStart = start.addingTimeInterval(TimeInterval(offset * 45 * 60))
        let periodEnd = periodStart.addingTimeInterval(20 * 60)
        return NightWatchRecord(
            id: UUID(),
            plan: NightWatchPlan.additionalQuiet(start: periodStart, end: periodEnd),
            startedAt: periodStart,
            endedAt: periodEnd,
            startMethod: .honorTimer,
            outcome: .completed,
            creditedWindDownMinutes: 20,
            role: .additionalQuiet,
            updatedAt: periodEnd
        )
    }
}
