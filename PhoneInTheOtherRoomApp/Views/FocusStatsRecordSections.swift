import SwiftUI

struct NightsRecordSection: View {
    @ObservedObject var viewModel: FocusRunViewModel
    let focusedRecordID: UUID?

    private var records: [NightWatchRecord] {
        viewModel.nightWatchRecords
    }

    private var latestPrimaryRecord: NightWatchRecord? {
        NightsHistoryAggregator.latestPrimaryRecord(from: records)
    }

    private var latestAdditionalRecord: NightWatchRecord? {
        NightsHistoryAggregator.latestAdditionalRecord(from: records)
    }

    private var focusedRecord: NightWatchRecord? {
        guard let focusedRecordID else { return nil }
        return records.first { $0.id == focusedRecordID && $0.outcome != .active }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            if let latestPrimaryRecord {
                NightsPrimaryResultCard(
                    record: latestPrimaryRecord,
                    eyebrow: latestPrimaryRecord.id == focusedRecordID
                        ? "ORIENTATION RECORD"
                        : "LATEST NIGHT"
                )
                .id(latestPrimaryRecord.id == focusedRecordID ? Self.anchor(for: latestPrimaryRecord.id) : nil)
            } else {
                emptyPrimaryCard
            }

            if let latestAdditionalRecord, shouldShowAdditional(latestAdditionalRecord) {
                NightsAdditionalResultRow(
                    record: latestAdditionalRecord,
                    isOrientationRecord: latestAdditionalRecord.id == focusedRecordID
                )
                .id(latestAdditionalRecord.id == focusedRecordID ? Self.anchor(for: latestAdditionalRecord.id) : nil)
            }

            if let focusedRecord, !isAlreadyPresented(focusedRecord) {
                if focusedRecord.occurrenceRole.isProgressionEligible {
                    NightsPrimaryResultCard(record: focusedRecord, eyebrow: "ORIENTATION RECORD")
                        .id(Self.anchor(for: focusedRecord.id))
                } else {
                    NightsAdditionalResultRow(record: focusedRecord, isOrientationRecord: true)
                        .id(Self.anchor(for: focusedRecord.id))
                }
            }
        }
    }

    static func anchor(for recordID: UUID) -> String {
        "nights-record-\(recordID.uuidString)"
    }

    private var emptyPrimaryCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Label("LATEST NIGHT", systemImage: "moon.stars.fill")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                Text("Your first protected night will settle here.")
                    .font(AppTypography.headline)
                Text("Quiet before bed and after waking will appear together after Wind Down.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
        }
    }

    private func shouldShowAdditional(_ additional: NightWatchRecord) -> Bool {
        guard let latestPrimaryRecord else { return true }
        return resultDate(additional) > resultDate(latestPrimaryRecord)
    }

    private func isAlreadyPresented(_ record: NightWatchRecord) -> Bool {
        record.id == latestPrimaryRecord?.id
            || (record.id == latestAdditionalRecord?.id && shouldShowAdditional(record))
    }

    private func resultDate(_ record: NightWatchRecord) -> Date {
        record.endedAt ?? record.updatedAt
    }
}

struct NightsPrimaryResultCard: View {
    let record: NightWatchRecord
    var eyebrow = "LATEST NIGHT"

    private var quietMinutes: Int {
        record.creditedWindDownMinutes + record.creditedMorningQuietMinutes
    }

    private var statusColor: Color {
        record.outcome == .completed ? AppColors.grass : AppColors.warning
    }

    private var statusTitle: String {
        record.outcome == .completed ? "Protected night" : "Ended early"
    }

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Label(eyebrow, systemImage: "moon.stars.fill")
                        .font(pixelFont(.caption))
                        .foregroundStyle(statusColor)
                    Spacer(minLength: AppSpacing.sm)
                    Text(record.plan.wakeTime.formatted(.dateTime.month(.abbreviated).day()))
                        .font(AppTypography.monoCaption)
                        .foregroundStyle(AppColors.muted)
                }

                Text(statusTitle)
                    .font(AppTypography.display(27))
                    .foregroundStyle(statusColor)
                Text("\(quietMinutes) min quiet")
                    .font(AppTypography.headline)

                NightsBookendBreakdown(
                    windDownMinutes: record.creditedWindDownMinutes,
                    morningMinutes: record.creditedMorningQuietMinutes
                )

                Text("Night ending \(record.plan.wakeTime.formatted(.dateTime.weekday(.wide).month(.wide).day()))")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(statusTitle), night ending \(record.plan.wakeTime.formatted(.dateTime.weekday(.wide).month(.wide).day()))")
        .accessibilityValue("\(record.creditedWindDownMinutes) minutes before bed, \(record.creditedMorningQuietMinutes) minutes after waking")
    }
}

private struct NightsBookendBreakdown: View {
    let windDownMinutes: Int
    let morningMinutes: Int

    var body: some View {
        HStack(spacing: 0) {
            bookend(
                title: "Before bed",
                minutes: windDownMinutes,
                systemImage: "moon.zzz.fill"
            )
            Divider()
                .padding(.vertical, AppSpacing.xs)
            bookend(
                title: "After waking",
                minutes: morningMinutes,
                systemImage: "sun.horizon.fill"
            )
        }
        .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.sm))
    }

    private func bookend(title: String, minutes: Int, systemImage: String) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: systemImage)
                .foregroundStyle(AppColors.grass)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(title)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                Text("\(minutes) min")
                    .font(AppTypography.headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.sm)
    }
}

struct NightsAdditionalResultRow: View {
    let record: NightWatchRecord
    var isOrientationRecord = false

    private var quietMinutes: Int {
        record.creditedWindDownMinutes + record.creditedMorningQuietMinutes
    }

    var body: some View {
        NavigationLink {
            WindDownRecordDetailView(record: record)
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "sparkles")
                    .font(AppTypography.title)
                    .foregroundStyle(AppColors.lavender)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(isOrientationRecord ? "Orientation quiet" : "Recent Phone Away")
                        .font(AppTypography.headline)
                    Text("\(quietMinutes) min · \(record.startedAt.formatted(.dateTime.weekday(.wide).month().day()))")
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
                    .stroke(AppColors.lavender.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOrientationRecord ? "Orientation quiet" : "Recent Phone Away")
        .accessibilityValue("\(quietMinutes) minutes on \(record.startedAt.formatted(.dateTime.weekday(.wide).month().day()))")
        .accessibilityHint("Opens the quiet-time record")
    }
}

#Preview("Latest night · protected") {
    NightsPrimaryResultCard(record: NightsRecordPreviewData.protected)
        .padding()
        .background(AppColors.paper)
}

#Preview("Latest night · ended early · dark") {
    NightsPrimaryResultCard(record: NightsRecordPreviewData.endedEarly)
        .padding()
        .background(AppColors.paper)
        .preferredColorScheme(.dark)
}

private enum NightsRecordPreviewData {
    static let bedtime = Date(timeIntervalSinceNow: -9 * 60 * 60)
    static let wake = Date(timeIntervalSinceNow: -2 * 60 * 60)
    static let plan = NightWatchPlan(
        intendedBedtime: bedtime,
        wakeTime: wake,
        protectedUntil: wake.addingTimeInterval(45 * 60),
        windDownMinutes: 60,
        morningQuietMinutes: 45,
        eveningActivity: .read,
        morningActivity: .openCurtains
    )
    static let protected = NightWatchRecord(
        id: UUID(),
        plan: plan,
        startedAt: bedtime.addingTimeInterval(-60 * 60),
        endedAt: plan.protectedUntil,
        startMethod: .honorTimer,
        outcome: .completed,
        creditedWindDownMinutes: 60,
        creditedMorningQuietMinutes: 45,
        updatedAt: plan.protectedUntil
    )
    static let endedEarly = NightWatchRecord(
        id: UUID(),
        plan: plan,
        startedAt: bedtime.addingTimeInterval(-30 * 60),
        endedAt: bedtime.addingTimeInterval(-10 * 60),
        startMethod: .honorTimer,
        outcome: .endedEarly,
        creditedWindDownMinutes: 20,
        updatedAt: bedtime.addingTimeInterval(-10 * 60)
    )
}
