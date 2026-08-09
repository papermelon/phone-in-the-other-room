import SwiftUI

struct NightsRecordSection: View {
    @ObservedObject var viewModel: FocusRunViewModel
    let focusedRecordID: UUID?

    private var completedRecords: [NightWatchRecord] {
        viewModel.nightWatchRecords
            .filter { $0.outcome != .active }
            .sorted { resultDate($0) > resultDate($1) }
    }

    private var latestRecord: NightWatchRecord? { completedRecords.first }

    private var latestProtectedRecord: NightWatchRecord? {
        completedRecords.first {
            $0.outcome == .completed && $0.occurrenceRole.isProgressionEligible
        }
    }

    private var orientationRecord: NightWatchRecord? {
        guard let focusedRecordID else { return nil }
        return completedRecords.first { $0.id == focusedRecordID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            latestResultCard

            if let latestProtectedRecord,
               latestProtectedRecord.id != latestRecord?.id {
                NightsResultCard(record: latestProtectedRecord, isLatest: false)
            }

            if let orientationRecord,
               orientationRecord.id != latestRecord?.id {
                orientationRecordCard(orientationRecord)
            }

            MorningCheckInCard(record: latestProtectedRecord)
                .environmentObject(viewModel)
        }
    }

    @ViewBuilder
    private var latestResultCard: some View {
        if let latestRecord {
            NightsResultCard(
                record: latestRecord,
                isOrientationRecord: latestRecord.id == focusedRecordID
            )
        } else {
            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Label("LATEST RESULT", systemImage: "moon.stars.fill")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text("Your first Wind Down will appear here.")
                        .font(AppTypography.headline)
                    Text("Counting Sheep records quiet time before bed and after waking. A one-time quiet period appears here separately from protected nights.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.muted)
                }
            }
        }
    }

    private func orientationRecordCard(_ record: NightWatchRecord) -> some View {
        NightsResultCard(record: record, isOrientationRecord: true)
            .id(Self.anchor(for: record.id))
    }

    static func anchor(for recordID: UUID) -> String { "nights-record-\(recordID.uuidString)" }

    private func resultDate(_ record: NightWatchRecord) -> Date {
        record.endedAt ?? record.updatedAt
    }
}

struct NightsResultCard: View {
    let record: NightWatchRecord
    var isOrientationRecord = false
    var isLatest = true

    private var isPrimary: Bool { record.occurrenceRole.isProgressionEligible }
    private var quietMinutes: Int {
        record.creditedWindDownMinutes + record.creditedMorningQuietMinutes
    }
    private var statusColor: Color {
        switch record.outcome {
        case .endedEarly: return AppColors.warning
        case .completed: return isPrimary ? AppColors.grass : AppColors.lavender
        case .active: return AppColors.muted
        }
    }

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(alignment: .top) {
                    Label(eyebrow, systemImage: isPrimary ? "moon.stars.fill" : "sparkles")
                        .font(pixelFont(.caption))
                        .foregroundStyle(statusColor)
                    Spacer()
                    Text(resultDate.formatted(.dateTime.month(.abbreviated).day()))
                        .font(AppTypography.monoCaption)
                        .foregroundStyle(AppColors.muted)
                }

                Text(statusTitle)
                    .font(isPrimary ? AppTypography.display(28) : AppTypography.headline)
                    .foregroundStyle(statusColor)
                Text("\(quietMinutes) min quiet")
                    .font(isPrimary ? AppTypography.headline : AppTypography.body)

                if isPrimary {
                    primaryBreakdown
                } else {
                    Text(additionalDescription)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.muted)
                }

                Text(finishedLabel)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)

                if record.outcome == .endedEarly {
                    Text("No protected night was added. Your record stays here, and nothing already found was lost.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
            }
        }
        .id(isOrientationRecord ? NightsRecordSection.anchor(for: record.id) : nil)
        .accessibilityElement(children: .contain)
    }

    private var statusTitle: String {
        switch record.outcome {
        case .endedEarly: return "Ended early"
        case .completed: return isPrimary ? "Protected night" : "One-time quiet period"
        case .active: return "In progress"
        }
    }

    private var eyebrow: String {
        if isOrientationRecord { return "ORIENTATION RECORD" }
        return isLatest ? "LATEST RESULT" : "LATEST PROTECTED NIGHT"
    }

    private var additionalDescription: String {
        if isOrientationRecord {
            return "Five minutes of practice quiet, recorded factually. It is real quiet time, but separate from protected-night progress and Ollie’s sheep search."
        }
        return "A bounded one-time quiet period outside the usual Wind Down. It is real quiet time, but does not become a protected night."
    }

    private var finishedLabel: String {
        let date = record.endedAt ?? record.updatedAt
        return "Finished \(date.formatted(.dateTime.weekday(.wide).month(.wide).day().hour().minute()))"
    }

    private var resultDate: Date { record.endedAt ?? record.updatedAt }

    private var primaryBreakdown: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("The two edges of this night")
                .font(AppTypography.caption.weight(.semibold))
                .foregroundStyle(AppColors.muted)
            HStack(spacing: AppSpacing.sm) {
                quietPart("Before bed", minutes: record.creditedWindDownMinutes, icon: "moon.zzz.fill")
                quietPart("After waking", minutes: record.creditedMorningQuietMinutes, icon: "sun.max.fill")
            }
        }
    }

    private func quietPart(_ label: String, minutes: Int, icon: String) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: icon)
                .foregroundStyle(AppColors.grass)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(label)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                Text("\(minutes) min")
                    .font(AppTypography.headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.sm)
        .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.sm))
    }
}

struct NightsSevenDaySection: View {
    @ObservedObject var viewModel: FocusRunViewModel

    private var summaries: [NightsSevenDaySummary] {
        let calendar = Calendar.current
        let records = viewModel.nightWatchRecords.filter { $0.outcome != .active }
        let grouped = Dictionary(grouping: records) {
            calendar.startOfDay(for: $0.plan.intendedBedtime)
        }
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return NightsSevenDaySummary(day: day, records: grouped[day] ?? [])
        }
    }

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Label("LAST 7 NIGHTS", systemImage: "calendar")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)

                HStack(spacing: AppSpacing.sm) {
                    metric("\(summaries.reduce(0) { $0 + $1.protectedNightCount })", label: "protected nights")
                    metric("\(summaries.reduce(0) { $0 + $1.protectedQuietMinutes })m", label: "protected quiet")
                    metric("\(summaries.reduce(0) { $0 + $1.additionalQuietCount })", label: "one-time periods")
                }

                VStack(spacing: AppSpacing.xs) {
                    ForEach(summaries) { summary in
                        summaryRow(summary)
                    }
                }

                Text("Quiet minutes here come from protected nights. One-time quiet periods are shown separately and do not become protected nights.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
        }
    }

    private func metric(_ value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(value)
                .font(AppTypography.display(25))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func summaryRow(_ summary: NightsSevenDaySummary) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Circle()
                .fill(summary.statusColor)
                .frame(width: 10, height: 10)
            Text(summary.day.formatted(.dateTime.weekday(.wide).month().day()))
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.muted)
            Spacer(minLength: AppSpacing.xs)
            Text(summary.statusLabel)
                .font(AppTypography.caption)
                .foregroundStyle(summary.records.isEmpty ? AppColors.muted : AppColors.ink)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(summary.day.formatted(.dateTime.weekday(.wide).month().day()))
        .accessibilityValue(summary.statusLabel)
    }
}

private struct NightsSevenDaySummary: Identifiable {
    let day: Date
    let records: [NightWatchRecord]

    var id: Date { day }
    var primaryRecords: [NightWatchRecord] { records.filter { $0.occurrenceRole.isProgressionEligible } }
    var protectedNightCount: Int { primaryRecords.filter { $0.outcome == .completed }.count }
    var protectedQuietMinutes: Int {
        primaryRecords.filter { $0.outcome == .completed }.reduce(0) {
            $0 + $1.creditedWindDownMinutes + $1.creditedMorningQuietMinutes
        }
    }
    var additionalQuietCount: Int { records.filter { $0.occurrenceRole == .additionalQuiet }.count }

    var statusColor: Color {
        if protectedNightCount > 0 { return AppColors.grass }
        if records.contains(where: { $0.outcome == .endedEarly }) { return AppColors.warning }
        if additionalQuietCount > 0 { return AppColors.lavender }
        return AppColors.surfaceMuted
    }

    var statusLabel: String {
        guard !records.isEmpty else { return "No record" }
        var labels: [String] = []
        if protectedNightCount > 0 {
            labels.append("Protected night · \(protectedQuietMinutes)m")
        }
        if records.contains(where: { $0.outcome == .endedEarly }) {
            labels.append("Ended early")
        }
        if additionalQuietCount > 0 {
            let minutes = records.filter { $0.occurrenceRole == .additionalQuiet }
                .reduce(0) { $0 + $1.creditedWindDownMinutes + $1.creditedMorningQuietMinutes }
            labels.append("One-time quiet · \(minutes)m")
        }
        return labels.joined(separator: " · ")
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
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("See the month")
                        .font(AppTypography.headline)
                    Text("Open a day-by-day record when you want more detail.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppColors.muted)
            }
            .padding(AppSpacing.md)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .stroke(AppColors.stroke.opacity(0.14), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the optional month view")
    }
}

#Preview("Nights record · protected · light") {
    NightsResultCard(record: NightsPreviewData.protectedRecord)
        .padding()
        .background(AppColors.paper)
        .preferredColorScheme(.light)
}

#Preview("Nights record · one-time quiet · dark") {
    NightsResultCard(
        record: NightsPreviewData.additionalRecord,
        isOrientationRecord: true
    )
    .padding()
    .background(AppColors.paper)
    .preferredColorScheme(.dark)
}

#Preview("Nights record · ended early") {
    NightsResultCard(record: NightsPreviewData.earlyRecord)
        .padding()
        .background(AppColors.paper)
}

private enum NightsPreviewData {
    static let bedtime = Date(timeIntervalSinceNow: -9 * 60 * 60)
    static let wake = Date(timeIntervalSinceNow: -2 * 60 * 60)

    static let primaryPlan = NightWatchPlan(
        intendedBedtime: bedtime,
        wakeTime: wake,
        protectedUntil: Date(timeIntervalSinceNow: -60 * 60),
        windDownMinutes: 30,
        morningQuietMinutes: 30,
        eveningActivity: .read,
        morningActivity: .openCurtains
    )

    static let protectedRecord = NightWatchRecord(
        id: UUID(),
        plan: primaryPlan,
        startedAt: Date(timeIntervalSinceNow: -9 * 60 * 60),
        endedAt: Date(timeIntervalSinceNow: -60 * 60),
        startMethod: .honorTimer,
        outcome: .completed,
        creditedWindDownMinutes: 30,
        creditedMorningQuietMinutes: 30,
        role: .primarySleepBookend
    )

    static let additionalRecord = NightWatchRecord(
        id: UUID(),
        plan: .additionalQuiet(
            start: Date(timeIntervalSinceNow: -20 * 60),
            end: Date(timeIntervalSinceNow: -15 * 60)
        ),
        startedAt: Date(timeIntervalSinceNow: -20 * 60),
        endedAt: Date(timeIntervalSinceNow: -15 * 60),
        startMethod: .honorTimer,
        outcome: .completed,
        creditedWindDownMinutes: 5,
        role: .additionalQuiet
    )

    static let earlyRecord = NightWatchRecord(
        id: UUID(),
        plan: primaryPlan,
        startedAt: Date(timeIntervalSinceNow: -9 * 60 * 60),
        endedAt: Date(timeIntervalSinceNow: -8 * 60 * 60),
        startMethod: .honorTimer,
        outcome: .endedEarly,
        creditedWindDownMinutes: 10,
        role: .primarySleepBookend
    )
}
