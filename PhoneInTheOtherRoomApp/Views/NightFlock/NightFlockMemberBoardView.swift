import SwiftUI

struct NightFlockMemberBoardView: View {
    let snapshot: NightFlockSnapshot

    private var rows: [NightFlockMemberBoardRow] {
        NightFlockMemberBoard.rows(from: snapshot) { id in
            WindDownGuidanceLibrary.items.first(where: { $0.id == id })?.title ?? id
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text("TONIGHT AND THE WEEK")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                Text("How the group is following through.")
                    .font(AppTypography.title)
                Text("Names stay inside this invited group. No update shared is not counted as completion.")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.secondaryText)

                ForEach(rows) { row in
                    memberCard(row)
                }
            }
            .padding(AppSpacing.md)
            .padding(.bottom, AppSpacing.xxl)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Group progress")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func memberCard(_ row: NightFlockMemberBoardRow) -> some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(row.alias).font(AppTypography.headline)
                Text(row.ready ? "Ready for tonight" : "Still getting set up")
                    .font(AppTypography.caption.weight(.semibold))
                Label(row.tonightStatus.title, systemImage: row.tonightStatus.symbolName)
                    .font(AppTypography.body)
                Text("Shared nights: \(row.qualifyingNights) of 7")
                    .font(AppTypography.caption)
                if row.windDownMinutes > 0 {
                    Text("Wind Down minutes: \(row.windDownMinutes)")
                        .font(AppTypography.caption)
                }
                if row.phoneAwayMinutes > 0 {
                    Text("Phone Away minutes: \(row.phoneAwayMinutes)")
                        .font(AppTypography.caption)
                }
                if let shielding = row.shieldingTitle {
                    Text(shielding).font(AppTypography.caption)
                }
                if let sleep = row.sleepMinutes {
                    Text("Sleep duration: \(sleep) min").font(AppTypography.caption)
                }
                if let rest = row.restfulnessTitle {
                    Text("How rested: \(rest)").font(AppTypography.caption)
                }
                if !row.sharedRoutineTitles.isEmpty {
                    Text("Shared ideas: " + row.sharedRoutineTitles.joined(separator: ", "))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }
}

struct NightFlockRewardsCard: View {
    let snapshot: NightFlockSnapshot

    private var qualifyingNights: Int {
        NightFlockRewardRules.qualifyingNightCount(
            in: snapshot.allMemberProgress,
            memberID: snapshot.myMemberID
        )
    }

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("SLUMBER PARTY GIFTS").font(pixelFont(.caption)).foregroundStyle(AppColors.grass)
                Text("Gifts for shared nights, not for opening the app.")
                    .font(AppTypography.headline)
                Text("A qualifying shared night can bring a little wool. Three nights bring a small Farm keepsake. Finishing seven nights with at least \(NightFlockRewardRules.sevenNightSearchThreshold) shared nights lets Ollie look for one missing sheep.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                Text("Your shared nights: \(qualifyingNights) of 7")
                    .font(AppTypography.caption.weight(.semibold))
                if snapshot.challenge.status == .completed {
                    Text("The seven nights are complete. Any waiting gifts will arrive when Counting Sheep can reach the pasture.")
                        .font(AppTypography.caption)
                }
                if !snapshot.pendingGrants.isEmpty {
                    Text("A gift is waiting to arrive on this iPhone.")
                        .font(AppTypography.caption.weight(.semibold))
                }
            }
        }
    }
}

#Preview("Group progress") {
    NavigationStack {
        NightFlockMemberBoardView(
            snapshot: NightFlockSnapshot(
                profile: NightFlockProfile(alias: "Moss"),
                flockID: UUID(),
                identity: .moonlitMeadow,
                myMemberID: UUID(),
                members: [NightFlockMember(id: UUID(), alias: "Moss", role: .keeper)],
                challenge: NightFlockChallenge(
                    id: UUID(),
                    timeZoneIdentifier: "UTC",
                    startsOn: NightFlockLocalDate(year: 2026, month: 8, day: 12),
                    status: .active,
                    sharedGoal: NightFlockSharedGoal(kind: .phoneAway)
                ),
                days: [],
                sharingEnabled: true
            )
        )
    }
}

#Preview("Group progress · empty") {
    NavigationStack {
        NightFlockMemberBoardView(
            snapshot: NightFlockSnapshot(
                profile: NightFlockProfile(alias: "Moss"),
                flockID: UUID(),
                identity: .moonlitMeadow,
                myMemberID: UUID(),
                members: [],
                challenge: NightFlockChallenge(
                    id: UUID(),
                    timeZoneIdentifier: "UTC",
                    startsOn: NightFlockLocalDate(year: 2026, month: 8, day: 12),
                    status: .pending
                ),
                days: [],
                sharingEnabled: true
            )
        )
    }
}
