import SwiftUI

struct SlumberPartySharedHabitMemberIdentity: Identifiable {
    let memberID: UUID
    let displayName: String
    let presentation: CountingSheepPublicPresentation
    let avatarID: String
    let isFormerMember: Bool

    var id: UUID { memberID }

    static func make(
        periods: [NightFlockSharedHabitPeriodSummary],
        members: [NightFlockV4Membership],
        records: [NightFlockSharedHabitRecord]
    ) -> [Self] {
        let current = Dictionary(grouping: members, by: \.memberID)
        let recorded = Dictionary(grouping: records, by: \.memberID)
        return Array(Set(periods.map(\.memberID))).sorted { $0.uuidString < $1.uuidString }.map { memberID in
            if let member = current[memberID]?.first {
                return Self(
                    memberID: memberID,
                    displayName: member.profile.displayName.isEmpty ? "A group member" : member.profile.displayName,
                    presentation: member.profile.presentation,
                    avatarID: member.profile.presentation.avatarID,
                    isFormerMember: false
                )
            }
            if let record = recorded[memberID]?.first {
                return Self(
                    memberID: memberID,
                    displayName: record.profileSnapshot.displayName.isEmpty ? "A former group member" : record.profileSnapshot.displayName,
                    presentation: .defaultValue,
                    avatarID: record.profileSnapshot.avatarID ?? "shepherd",
                    isFormerMember: record.isFormerMember
                )
            }
            return Self(
                memberID: memberID,
                displayName: "A group member",
                presentation: .defaultValue,
                avatarID: "shepherd",
                isFormerMember: false
            )
        }
    }
}

struct SlumberPartySharedHabitsSummaryGrid: View {
    let periods: [NightFlockSharedHabitPeriodSummary]
    var identities: [SlumberPartySharedHabitMemberIdentity] = []
    @State private var selectedPeriod: NightFlockSharedHabitPeriodSummary.Period = .lastNight
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if periods.isEmpty {
            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("No summaries yet")
                        .font(AppTypography.headline)
                    Text("A summary appears after an eligible observed night. An empty space does not mean anyone missed a habit.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                periodPicker
                ForEach(resolvedIdentities) { identity in
                    let memberPeriods = periods.filter { $0.memberID == identity.memberID }
                    PixelCard {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            identityHeader(identity)
                            compactSummary(memberPeriods)
                            DisclosureGroup("More shared detail") {
                                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                    ForEach(memberPeriods.indices, id: \.self) { index in
                                        detailedSummaryRow(memberPeriods[index])
                                    }
                                }
                                .padding(.top, AppSpacing.sm)
                            }
                            .font(AppTypography.caption.weight(.semibold))
                        }
                    }
                }
            }
        }
    }

    private var periodPicker: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppSpacing.xs) {
                periodButton(.lastNight)
                periodButton(.last7Nights)
                periodButton(.last30Nights)
            }
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                periodButton(.lastNight)
                HStack(spacing: AppSpacing.xs) {
                    periodButton(.last7Nights)
                    periodButton(.last30Nights)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Shared habit period")
    }

    private func periodButton(_ period: NightFlockSharedHabitPeriodSummary.Period) -> some View {
        Button(periodPickerTitle(period)) { selectedPeriod = period }
            .font(AppTypography.caption)
            .frame(maxWidth: .infinity, minHeight: 40)
            .buttonStyle(PixelChipButtonStyle(isSelected: selectedPeriod == period))
            .accessibilityAddTraits(selectedPeriod == period ? .isSelected : [])
    }

    private var resolvedIdentities: [SlumberPartySharedHabitMemberIdentity] {
        identities.isEmpty
            ? SlumberPartySharedHabitMemberIdentity.make(periods: periods, members: [], records: [])
            : identities
    }

    private func identityHeader(_ identity: SlumberPartySharedHabitMemberIdentity) -> some View {
        HStack(spacing: AppSpacing.sm) {
            SlumberPartySocialAvatarView(
                presentation: identity.presentation,
                avatarID: identity.avatarID,
                size: 48
            )
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(identity.displayName)
                    .font(AppTypography.headline)
                if identity.isFormerMember {
                    Text("Former member")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                }
            }
            Spacer(minLength: AppSpacing.sm)
        }
        .accessibilityElement(children: .combine)
    }

    private func compactSummary(_ summaries: [NightFlockSharedHabitPeriodSummary]) -> some View {
        let sleep = summary(kind: .sleep, period: selectedPeriod, in: summaries)
        let windDown = summary(kind: .windDown, period: selectedPeriod, in: summaries)
        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(selectedPeriod == .lastNight ? "SLEEP DURATION" : "SLEEP DURATION MEAN")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                    Text(sleep?.averageMinutes.map(NightFlockSharedHabitPresentation.meanDurationText) ?? "No data")
                        .font(AppTypography.title)
                    Text(coverage(sleep))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                }
                Spacer(minLength: AppSpacing.sm)
                VStack(alignment: .trailing, spacing: AppSpacing.xxs) {
                    Text(selectedPeriod == .lastNight ? "NIGHT ENDING" : "PERIOD")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                    Text(selectedPeriod == .lastNight
                         ? dateTitle(sleep?.endingOn)
                         : periodPickerTitle(selectedPeriod))
                        .font(AppTypography.body.weight(.semibold))
                        .multilineTextAlignment(.trailing)
                }
            }
            if selectedPeriod == .lastNight {
                Text("The next sleep summary updates after noon in the contributor’s saved time zone.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                windDownLine(windDown)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func windDownLine(_ summary: NightFlockSharedHabitPeriodSummary?) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("WIND DOWN")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                Text(summary?.averageMinutes.map(NightFlockSharedHabitPresentation.meanDurationText) ?? "No observed summary")
                    .font(AppTypography.body.weight(.semibold))
            }
            Spacer(minLength: AppSpacing.sm)
            Text(coverage(summary))
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }

    private func detailedSummaryRow(_ summary: NightFlockSharedHabitPeriodSummary) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("\(NightFlockSharedHabitPresentation.kindTitle(summary.kind)) · \(NightFlockSharedHabitPresentation.periodTitle(summary.period))")
                    .font(AppTypography.caption.weight(.semibold))
                Text(NightFlockSharedHabitPresentation.methodTitle(summary.method))
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
            }
            Spacer(minLength: AppSpacing.sm)
            Text("\(summary.averageMinutes.map(NightFlockSharedHabitPresentation.meanDurationText) ?? "No data") · \(coverage(summary))")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }

    private func summary(
        kind: NightFlockSharedHabitKind,
        period: NightFlockSharedHabitPeriodSummary.Period,
        in summaries: [NightFlockSharedHabitPeriodSummary]
    ) -> NightFlockSharedHabitPeriodSummary? {
        summaries.first { $0.kind == kind && $0.period == period }
    }

    private func coverage(_ summary: NightFlockSharedHabitPeriodSummary?) -> String {
        guard let summary else { return "No coverage" }
        return "\(summary.coveredNights) of \(summary.availableNights) nights"
    }

    private func dateTitle(_ date: NightFlockLocalDate?) -> String {
        guard let date else { return "unknown" }
        return NightFlockSharedHabitPresentation.localDateText(date)
    }

    private func periodPickerTitle(_ period: NightFlockSharedHabitPeriodSummary.Period) -> String {
        switch period {
        case .lastNight: "Last night"
        case .last7Nights: "7 nights"
        case .last30Nights: "30 nights"
        }
    }
}

struct SlumberPartySharedHabitsArchive: View {
    let records: [NightFlockSharedHabitRecord]

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("ARCHIVE")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                if records.isEmpty {
                    Text("No shared records yet")
                        .font(AppTypography.headline)
                    Text("When someone agrees and an eligible observation is available, a dated summary appears here.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(records) { record in
                        archiveRow(record)
                    }
                }
            }
        }
    }

    private func archiveRow(_ record: NightFlockSharedHabitRecord) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                if let outcome = record.outcome {
                    Text(outcomeTitle(outcome))
                }
                if record.evidence == .appRecorded, let protectionMinutes = record.protectionMinutes {
                    Text("App-recorded protection: \(NightFlockSharedHabitPresentation.durationText(protectionMinutes))")
                    Text("Observed pre-bed shielding only; it does not show exact app use or verify sleep adherence.")
                } else {
                    Text("No observed protection evidence")
                }
            }
            .font(AppTypography.caption)
            .foregroundStyle(AppColors.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, AppSpacing.xxs)
        } label: {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(record.profileSnapshot.displayName.isEmpty ? "A group member" : record.profileSnapshot.displayName)
                        .font(AppTypography.body.weight(.semibold))
                    Text("\(kindTitle(record.kind)) · \(dateTitle(for: record))")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                    if record.isFormerMember {
                        Text("Former member")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondaryText)
                    }
                }
                Spacer(minLength: AppSpacing.sm)
                Text(NightFlockSharedHabitPresentation.durationText(record.minutes))
                    .font(AppTypography.body.weight(.semibold))
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func kindTitle(_ kind: NightFlockSharedHabitKind) -> String {
        NightFlockSharedHabitPresentation.kindTitle(kind)
    }

    private func dateTitle(for record: NightFlockSharedHabitRecord) -> String {
        if record.kind == .phoneAway {
            if let activityDate = record.activityDate ?? record.localDate {
                return "Activity day \(NightFlockSharedHabitPresentation.localDateText(activityDate))"
            }
            return "Earlier shared activity"
        }
        if let localDate = record.localDate {
            return "Night ending \(NightFlockSharedHabitPresentation.localDateText(localDate))"
        }
        return "Earlier shared activity"
    }

    private func outcomeTitle(_ outcome: NightFlockSharedHabitOutcome) -> String {
        switch outcome {
        case .completed: "Completed"
        case .partlyCompleted: "Partly completed"
        }
    }
}

#Preview("Shared habits ready") {
    ScrollView {
        SlumberPartySharedHabitsArchive(records: [
            NightFlockSharedHabitRecord(
                recordID: UUID(), partyID: UUID(), memberID: UUID(), sourceID: nil,
                revision: 1, kind: .windDown,
                localDate: NightFlockLocalDate(year: 2026, month: 8, day: 28),
                timeZoneIdentifier: "Asia/Singapore", minutes: 30, outcome: .completed,
                protectionMinutes: 25, evidence: .appRecorded,
                profileSnapshot: NightFlockSharedHabitProfileSnapshot(displayName: "Moss", avatarID: "ollie"),
                isFormerMember: false, migratedAt: nil
            )
        ])
        .padding()
    }
    .background(AppColors.paper)
}

#Preview("Shared habits empty") {
    SlumberPartySharedHabitsSummaryGrid(periods: [])
        .padding()
        .background(AppColors.paper)
}
