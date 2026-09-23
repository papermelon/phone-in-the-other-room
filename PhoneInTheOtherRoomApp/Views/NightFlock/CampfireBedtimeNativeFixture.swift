#if DEBUG
import SwiftUI

/// Release scene and clock, with no service or account effects.
struct CampfireBedtimeNativeFixture: View {
    let mode: String
    @State private var party: NightFlockV4PartyDetail

    init(mode: String = "bedtime") {
        self.mode = mode
        let now = Date()
        var party = SlumberPartySharedFarmFixtures.party
        let names = ["Clover", "Moss", "Fern", "Willow", "Juniper", "Hazel", "Rowan", "River"]
        let count = mode == "bedtime-eight" ? 8 : mode == "bedtime-solo" ? 1 : mode == "bedtime-four" ? 4 : 3
        party.memberships = (0..<count).map { index in
            var appearance = CountingSheepPublicPresentation.defaultValue
            appearance.headShapeID = ShepherdHeadShape.allCases[index % ShepherdHeadShape.allCases.count].rawValue
            appearance.skinToneID = ShepherdSkinTone.allCases[index % ShepherdSkinTone.allCases.count].rawValue
            appearance.hairStyleID = ShepherdHairStyle.allCases[index % ShepherdHairStyle.allCases.count].rawValue
            appearance.shepherdOutfitID = ["shepherd_moss_coat", "shepherd_field_overalls", "shepherd_moon_coat", "shepherd_star_keeper_cloak"][index % 4]
            appearance.shepherdAccessoryID = ["shepherd_moon_beanie", "none", "shepherd_clover_headscarf", "shepherd_wool_hat"][index % 4]
            return .init(memberID: UUID(), profile: .init(displayName: names[index], presentation: appearance),
                         role: .member, joinedAt: now.addingTimeInterval(-86400))
        }
        let sessions = party.memberships.enumerated().map { index, member in
            CampfireSession(id: UUID(), memberID: member.memberID, kind: index == 2 ? .phoneAway : .windDown,
                activity: index == 2 ? .reading : nil, startedAt: now.addingTimeInterval(-120), observedAt: now,
                expiresAt: now.addingTimeInterval(mode == "bedtime-boundary" ? 20 : 3600), ended: mode == "bedtime-ended", revision: mode == "bedtime-ended" ? 2 : 1,
                intendedBedtime: mode == "bedtime-legacy" || index == 2 ? nil : now.addingTimeInterval(mode == "bedtime-boundary" ? 8 : index == 0 && mode != "bedtime-solo" ? 1800 : -60))
        }
        party.pasture = .init(memberEpochID: UUID(), entities: [], visits: [], lantern: .init(contributions: 0, requiredContributions: 12),
            campfire: .init(sessions: sessions, supportsIntendedBedtime: true))
        _party = State(initialValue: party)
    }

    var body: some View {
        ScrollView {
            SlumberPartyV4PresentationClock(party: party) { date in
                let sessions = CampfireRules.currentSessions(party.pasture?.campfire,
                    members: Set(party.memberships.map(\.memberID)), isFresh: mode != "bedtime-stale", at: date)
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("Campfire").font(AppTypography.title)
                    if sessions.isEmpty {
                        Text(mode == "bedtime-stale" ? "Refresh to see current sessions." : "A quiet spot is waiting").font(AppTypography.body)
                    } else {
                        CampfireSceneView(people: sessions.compactMap { session in
                            party.memberships.first { $0.memberID == session.memberID }.map {
                                .init(id: session.id, name: $0.profile.displayName, appearance: $0.profile.presentation,
                                      detail: session.title, pose: session.pose(at: date))
                            }
                        }, onSelect: { _ in })
                        ForEach(sessions) { session in
                            if let member = party.memberships.first(where: { $0.memberID == session.memberID }) {
                                CampfirePersonRow(name: member.profile.displayName, appearance: member.profile.presentation,
                                    detail: session.title, pose: session.pose(at: date))
                            }
                        }
                    }
                    if mode == "bedtime-solo", let member = party.memberships.first {
                        CampfireShepherdView(presentation: member.profile.presentation, pose: .bedtime, size: 220, motionEnabled: false)
                            .frame(maxWidth: .infinity)
                    }
                }.padding(AppSpacing.md)
            }
        }.background(AppColors.paper.ignoresSafeArea())
    }
}

#Preview("Campfire · mixed bedtime") { CampfireBedtimeNativeFixture() }
#Preview("Campfire · eight customized Shepherds") { CampfireBedtimeNativeFixture(mode: "bedtime-eight") }
#Preview("Campfire · stale") { CampfireBedtimeNativeFixture(mode: "bedtime-stale") }
#Preview("Campfire · legacy awake") { CampfireBedtimeNativeFixture(mode: "bedtime-legacy") }
#Preview("Campfire · boundary without network") { CampfireBedtimeNativeFixture(mode: "bedtime-boundary") }
#Preview("Campfire · large text") { CampfireBedtimeNativeFixture().dynamicTypeSize(.accessibility5) }
#endif
