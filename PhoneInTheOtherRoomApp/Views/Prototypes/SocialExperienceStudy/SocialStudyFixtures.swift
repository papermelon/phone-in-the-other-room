#if DEBUG
import Foundation

/// The fixture set the handoff asked for. Every case renders through the same
/// three surfaces; nothing here represents real accounts or server data.
enum SocialStudyFixture: String, CaseIterable, Identifiable {
    case quiet, twoSessions, eightPeople, sharingOff, loading, failed, stale, returnCheckIn
    var id: String { rawValue }

    var title: String {
        switch self {
        case .quiet: return "No active sessions"
        case .twoSessions: return "One Wind Down + one Phone Away"
        case .eightPeople: return "Eight people"
        case .sharingOff: return "Own sharing off"
        case .loading: return "Loading"
        case .failed: return "Failed"
        case .stale: return "Stale"
        case .returnCheckIn: return "Return / check-in"
        }
    }

    var scenario: SocialStudyScenario { SocialStudyFixtures.scenario(for: self) }
}

enum SocialStudyFixtures {
    static let now = Date(timeIntervalSince1970: 1_789_480_800) // 15 Sep 2026, 14:00 UTC = 22:00 SGT

    // Stable IDs keep previews deterministic and let the log stay readable.
    static let me = UUID(uuidString: "A1000000-0000-4000-8000-000000000001")!
    static let papa = UUID(uuidString: "A1000000-0000-4000-8000-000000000002")!
    static let tommy = UUID(uuidString: "A1000000-0000-4000-8000-000000000003")!
    static let publicIDs = (1...8).map { UUID(uuidString: String(format: "B1000000-0000-4000-8000-%012d", $0))! }

    static func appearance(skin: String, hair: String, head: String? = nil, outfit: String? = nil, accessory: String? = nil) -> CountingSheepPublicPresentation {
        var value = CountingSheepPublicPresentation.defaultValue
        value.avatarID = "shepherd"
        value.skinToneID = skin
        value.hairStyleID = hair
        if let head { value.headShapeID = head }
        if let outfit { value.shepherdOutfitID = outfit }
        if let accessory { value.shepherdAccessoryID = accessory }
        return value
    }

    static let partyName = "Nangmi Family"

    static var partyMembers: [StudyPerson] {
        [
            StudyPerson(id: me, name: "You", presentation: appearance(skin: "warm", hair: "waves", head: "round", outfit: "shepherd_moon_coat"), isMe: true, audience: .party(name: partyName)),
            StudyPerson(id: papa, name: "Papa", presentation: appearance(skin: "deep", hair: "curls", outfit: "shepherd_field_overalls"), audience: .party(name: partyName)),
            StudyPerson(id: tommy, name: "Tommy", presentation: appearance(skin: "warm", hair: "long", accessory: "shepherd_moon_beanie"), audience: .party(name: partyName))
        ]
    }

    static let publicNames = ["Fern", "Juniper", "Rowan", "Willow", "Hazel", "River", "Sage", "Wren"]
    static let publicSkins = ["warm", "deep", "warm", "deep", "warm", "deep", "warm", "deep"]
    static let publicHair = ["coils", "waves", "long", "curls", "coils", "long", "waves", "curls"]

    static func publicPeople(count: Int) -> [StudyPerson] {
        (0..<count).map { index in
            StudyPerson(id: publicIDs[index], name: publicNames[index],
                        presentation: appearance(skin: publicSkins[index], hair: publicHair[index]),
                        audience: .publicCampfire,
                        connection: index == 1 ? .accepted : (index == 2 ? .requestedByThem : .none))
        }
    }

    static var myFlock: [StudyFlockSheep] {
        [
            StudyFlockSheep(id: UUID(uuidString: "C1000000-0000-4000-8000-000000000001")!, definitionID: "mabel", name: "Mabel", visitingPartyName: partyName),
            StudyFlockSheep(id: UUID(uuidString: "C1000000-0000-4000-8000-000000000002")!, definitionID: "pippin", name: "Pippin"),
            StudyFlockSheep(id: UUID(uuidString: "C1000000-0000-4000-8000-000000000003")!, definitionID: "oat", name: "Oat"),
            StudyFlockSheep(id: UUID(uuidString: "C1000000-0000-4000-8000-000000000004")!, definitionID: "clementine", name: "Clementine")
        ]
    }

    static var visitingSheep: [StudyVisitingSheep] {
        [
            StudyVisitingSheep(id: UUID(uuidString: "D1000000-0000-4000-8000-000000000001")!, definitionID: "mabel", name: "Mabel", ownerID: me),
            StudyVisitingSheep(id: UUID(uuidString: "D1000000-0000-4000-8000-000000000002")!, definitionID: "bramble", name: "Bramble", ownerID: papa)
        ]
    }

    static var records: [StudyRecord] {
        [
            StudyRecord(personID: tommy, kind: .windDown, roundedMinutes: nil, occurredAt: now.addingTimeInterval(-14.5 * 3600)),
            StudyRecord(personID: papa, kind: .phoneAway, roundedMinutes: 45, occurredAt: now.addingTimeInterval(-26 * 3600))
        ]
    }

    static func partySession(_ person: UUID, kind: StudySessionKind, hours: Double, intention: String? = nil, activity: CampfireActivity? = nil, asksForBuddy: Bool = false, buddy: UUID? = nil, encouragement: Int = 0) -> StudySession {
        // Deterministic per person so scenario equality and logs stay stable.
        let slot = Int(person.uuidString.suffix(2), radix: 16) ?? 0
        return StudySession(id: UUID(uuidString: String(format: "E1000000-0000-4000-8000-%012d", slot))!,
                     personID: person, kind: kind, activity: activity, intention: intention,
                     startedAt: now.addingTimeInterval(-20 * 60), endsAt: now.addingTimeInterval(hours * 3600),
                     asksForBuddy: asksForBuddy, buddyPersonID: buddy, encouragementCount: encouragement)
    }

    static func publicSessions(for people: [StudyPerson]) -> [StudySession] {
        let plans: [(StudySessionKind, CampfireActivity?, Double)] = [
            (.windDown, nil, 8.5), (.phoneAway, .reading, 1.2), (.phoneAway, .studying, 2.5), (.windDown, nil, 9),
            (.phoneAway, .reading, 0.4), (.phoneAway, .making, 3), (.windDown, nil, 7.5), (.phoneAway, .resting, 0.9)
        ]
        return people.enumerated().map { index, person in
            let plan = plans[index % plans.count]
            return StudySession(id: UUID(uuidString: String(format: "F1000000-0000-4000-8000-%012d", index + 1))!,
                                personID: person.id, kind: plan.0, activity: plan.1,
                                startedAt: now.addingTimeInterval(-Double(index + 1) * 600),
                                endsAt: now.addingTimeInterval(plan.2 * 3600),
                                encouragementCount: index % 3, encouragedByMe: index == 3)
        }
    }

    static func gatherings(windDown: Int, reading: Int, studying: Int, making: Int, resting: Int) -> [StudyGathering] {
        [.init(title: "Wind Down", count: windDown), .init(title: "Reading", count: reading), .init(title: "Studying", count: studying),
         .init(title: "Making", count: making), .init(title: "Resting", count: resting)]
    }

    static func scenario(for fixture: SocialStudyFixture) -> SocialStudyScenario {
        var group = StudyGroup(name: partyName, members: partyMembers, myID: me, roundNight: 3, visitingSheep: visitingSheep,
                               lanternContributions: 5, recentRecords: records, sessions: [])
        var campfirePeople = publicPeople(count: 4)
        var campfire = StudyCampfire(totalWindDown: 31, totalPhoneAway: 12,
                                     gatherings: gatherings(windDown: 31, reading: 8, studying: 3, making: 1, resting: 0),
                                     selectedGathering: "Reading", participants: campfirePeople,
                                     sessions: publicSessions(for: campfirePeople), state: .current(observedAt: now.addingTimeInterval(-40)),
                                     publicAgreementAccepted: true, savedAudience: .myParties, myPublicName: "Fern")
        var own: StudySession?
        var pending: StudySession?
        var groupState: StudyDataState = .current(observedAt: now.addingTimeInterval(-30))
        var title = fixture.title
        var summary = ""

        switch fixture {
        case .quiet:
            campfirePeople = []
            campfire.participants = []
            campfire.sessions = []
            campfire.totalWindDown = 3; campfire.totalPhoneAway = 0
            campfire.gatherings = gatherings(windDown: 3, reading: 0, studying: 0, making: 0, resting: 0)
            summary = "An established private group with nobody sharing; a public fire with an empty Reading gathering."
        case .twoSessions:
            group.sessions = [
                partySession(papa, kind: .windDown, hours: 9, intention: "Lights out by half ten", asksForBuddy: true, encouragement: 1),
                partySession(tommy, kind: .phoneAway, hours: 0.75, intention: "Finish the chemistry chapter", activity: .studying, buddy: papa)
            ]
            summary = "Papa is winding down and Tommy is on Phone Away. The public fire has four people."
        case .eightPeople:
            campfirePeople = publicPeople(count: 8)
            campfire.participants = campfirePeople
            campfire.sessions = publicSessions(for: campfirePeople)
            campfire.selectedGathering = "Wind Down"
            campfire.totalWindDown = 140; campfire.totalPhoneAway = 57
            campfire.gatherings = gatherings(windDown: 140, reading: 22, studying: 9, making: 4, resting: 6)
            for index in 3..<8 {
                group.members.append(StudyPerson(id: publicIDs[index], name: ["Amma", "Dolma", "Tenzin", "Pema", "Norbu"][index - 3],
                                                 presentation: appearance(skin: publicSkins[index], hair: publicHair[index]),
                                                 audience: .party(name: partyName)))
            }
            group.sessions = [partySession(papa, kind: .windDown, hours: 8), partySession(group.members[4].id, kind: .phoneAway, hours: 1.5, activity: .reading),
                              partySession(group.members[6].id, kind: .windDown, hours: 8.2)]
            summary = "Eight seats at one public fire and an eight-member party with three people sharing."
        case .sharingOff:
            group.partySharingOn = false
            campfire.publicAgreementAccepted = false
            campfire.savedAudience = .justMe
            campfire.myPublicName = ""
            group.sessions = [partySession(papa, kind: .windDown, hours: 9)]
            summary = "I browse both places without sharing. Others' sessions remain visible; my start defaults to just me."
        case .loading:
            groupState = .loading
            campfire.state = .loading
            summary = "First open before any observation arrives."
        case .failed:
            groupState = .failed(reason: "The shared record couldn’t be reached. Your own timer and Farm are unaffected.")
            campfire.state = .failed(reason: "Campfire couldn’t be reached. Nothing about you was sent.")
            summary = "Both places fail truthfully and offer a retry; local protection continues."
        case .stale:
            groupState = .stale(lastObservedAt: now.addingTimeInterval(-25 * 60))
            campfire.state = .stale(lastObservedAt: now.addingTimeInterval(-25 * 60))
            group.sessions = [partySession(papa, kind: .windDown, hours: 9)]
            summary = "Records from 25 minutes ago are shown as last seen, never as current presence."
        case .returnCheckIn:
            title = "Return / check-in"
            own = nil
            var finished = partySession(me, kind: .phoneAway, hours: -0.2, intention: "Read one chapter", activity: .reading, buddy: papa, encouragement: 2)
            finished.ended = true
            finished.checkInRequested = true
            pending = finished
            var papaDone = partySession(papa, kind: .windDown, hours: -1)
            papaDone.ended = true
            papaDone.outcome = .madeProgress
            papaDone.reflection = "Fell asleep before the last page."
            group.sessions = [finished, papaDone]
            campfirePeople = publicPeople(count: 3)
            campfire.participants = campfirePeople
            campfire.sessions = publicSessions(for: campfirePeople)
            summary = "Morning after: my check-in is due, Papa shared a result, and Juniper from last night's public fire is an accepted connection."
        }
        return SocialStudyScenario(title: title, summary: summary, now: now, group: group, groupState: groupState, campfire: campfire,
                                   myFlock: myFlock, ownSession: own, pendingCheckIn: pending)
    }
}
#endif
