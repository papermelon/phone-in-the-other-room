import SwiftUI

struct WindDownDayDetailView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    let day: Date
    let records: [NightWatchRecord]
    @State private var showsPrimaryRecords = false
    @State private var showsAdditionalRecords = false

    private var summary: NightsHistoryDay {
        NightsHistoryAggregator.summary(for: day, from: records)
    }

    private var primaryRecords: [NightWatchRecord] {
        records.filter { $0.occurrenceRole.isProgressionEligible }
    }

    private var additionalRecords: [NightWatchRecord] {
        records.filter { $0.occurrenceRole == .additionalQuiet }
    }

    private var screenFreeMorningOccurrences: [MorningQuietOccurrence] {
        viewModel.screenFreeMorningOccurrences(on: day)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text(day.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                    .font(AppTypography.display(28))

                daySummary

                if primaryRecords.isEmpty && additionalRecords.isEmpty {
                    PixelCard {
                        Text("No completed quiet periods were recorded for this day.")
                            .font(AppTypography.body)
                    }
                } else {
                    occurrenceGroup(
                        title: "USUAL WIND DOWN",
                        records: primaryRecords,
                        totalMinutes: summary.primaryQuietMinutes,
                        accent: AppColors.grass,
                        isExpanded: $showsPrimaryRecords
                    )
                    occurrenceGroup(
                        title: "PHONE AWAY",
                        records: additionalRecords,
                        totalMinutes: summary.additionalQuietMinutes,
                        accent: AppColors.lavender,
                        isExpanded: $showsAdditionalRecords
                    )
                    screenFreeMorningGroup
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

    private func morningStatus(_ occurrence: MorningQuietOccurrence) -> String {
        switch occurrence.outcome {
        case .scheduled: return "Planned"
        case .active: return "In progress"
        case .skipped: return "Skipped"
        case .finished: return "Finished"
        }
    }

    private func morningDetail(_ occurrence: MorningQuietOccurrence) -> String {
        let minutes = occurrence.eligibleElapsedMinutes(at: occurrence.endedAt ?? Date())
        if occurrence.outcome == .finished, minutes < SunriseTrailRules.minimumOccurrenceMinutes {
            return "\(minutes) actual minutes · below the 15-minute Sunrise Trail minimum"
        }
        return "\(minutes) actual minutes · tracked independently from Wind Down"
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
                                Image(systemName: records.first?.occurrenceRole == .additionalQuiet ? "sparkles" : "moon.stars.fill")
                                    .foregroundStyle(accent)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                    Text("\(records.count) periods · \(totalMinutes) min recorded")
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

    private var summaryTitle: String {
        switch summary.primaryOutcome {
        case .protected: return "Wind Down completed"
        case .endedEarly: return "Ended early"
        case nil: return summary.additionalCount > 0 ? "Phone Away" : "No recorded quiet"
        }
    }

    private var summaryDetail: String {
        var parts: [String] = []
        if summary.primaryAttemptCount > 0 {
            parts.append("\(summary.primaryAttemptCount) usual Wind Down attempt\(summary.primaryAttemptCount == 1 ? "" : "s")")
        }
        if summary.primaryOutcome == .protected, summary.earlyEndedPrimaryCount > 0 {
            parts.append("\(summary.earlyEndedPrimaryCount) ended early")
        }
        if summary.additionalCount > 0 {
            parts.append("\(summary.additionalCount) one-time period\(summary.additionalCount == 1 ? "" : "s")")
        }
        parts.append("\(summary.recordedQuietMinutes) min recorded quiet")
        return parts.joined(separator: " · ")
    }

    private var summarySystemImage: String {
        switch summary.primaryOutcome {
        case .protected: return "shield.fill"
        case .endedEarly: return "moon.stars.fill"
        case nil: return summary.additionalCount > 0 ? "sparkles" : "minus"
        }
    }

    private var summaryColor: Color {
        switch summary.primaryOutcome {
        case .protected: return AppColors.grass
        case .endedEarly: return AppColors.warning
        case nil: return summary.additionalCount > 0 ? AppColors.lavender : AppColors.muted
        }
    }
}

struct WindDownOccurrenceRow: View {
    let record: NightWatchRecord

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: record.occurrenceRole == .additionalQuiet ? "sparkles" : "moon.stars.fill")
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
        let intervals = record.creditedIntervals
        if let first = intervals.first, let last = intervals.last {
            return "\(OllieFormat.timeRange(from: first.start, to: last.end)) · \(quietMinutes) min"
        }
        let end = record.endedAt ?? record.updatedAt
        guard end > record.startedAt else { return OllieFormat.time(record.startedAt) }
        return OllieFormat.timeRange(from: record.startedAt, to: end)
    }

    private var quietMinutes: Int {
        record.creditedWindDownMinutes + record.creditedMorningQuietMinutes
    }

    private var statusLabel: String {
        record.outcome == .completed ? "Completed" : "Ended early"
    }

    private var statusColor: Color {
        if record.outcome == .endedEarly { return AppColors.warning }
        return record.occurrenceRole == .additionalQuiet ? AppColors.lavender : AppColors.grass
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
                        if record.occurrenceRole == .additionalQuiet {
                            detailMetric("Phone-away time", value: "\(record.creditedWindDownMinutes + record.creditedMorningQuietMinutes) min")
                        } else {
                            detailMetric("Quiet before bed", value: "\(record.creditedWindDownMinutes) min")
                            detailMetric("Quiet after waking", value: "\(record.creditedMorningQuietMinutes) min")
                            detailMetric("Total quiet", value: "\(record.creditedWindDownMinutes + record.creditedMorningQuietMinutes) min")
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
