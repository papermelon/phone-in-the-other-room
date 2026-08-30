import XCTest

final class WindDownGuidanceTests: XCTestCase {
    func testEveryGuidanceItemHasSourceAndShortBody() {
        XCTAssertFalse(WindDownGuidanceLibrary.items.isEmpty)
        XCTAssertTrue(WindDownGuidanceLibrary.items.allSatisfy { !$0.sourceIDs.isEmpty })
        XCTAssertTrue(WindDownGuidanceLibrary.items.allSatisfy { $0.body.count <= 180 })
        XCTAssertEqual(Set(WindDownGuidanceLibrary.items.map(\.id)).count, WindDownGuidanceLibrary.items.count)
        XCTAssertTrue(WindDownGuidanceLibrary.items.allSatisfy {
            $0.sourceIDs.allSatisfy { WindDownGuidanceSourceRegistry.source(for: $0) != nil }
        })
    }

    func testMealAndCaffeineCardsAreWindDownOnlyAndNonPrescriptive() throws {
        let meal = try XCTUnwrap(WindDownGuidanceLibrary.items.first { $0.id == "leave-room-after-heavy-meal" })
        let caffeine = try XCTUnwrap(WindDownGuidanceLibrary.items.first { $0.id == "personal-caffeine-cutoff" })
        XCTAssertEqual(meal.phase, .windDown)
        XCTAssertEqual(caffeine.phase, .windDown)
        XCTAssertEqual(meal.sourceIDs, ["nhlbi-healthy-sleep"])
        XCTAssertEqual(caffeine.sourceIDs, ["nhlbi-healthy-sleep"])
        XCTAssertFalse(meal.body.contains("must"))
        XCTAssertFalse(caffeine.body.contains("must"))
        XCTAssertFalse(caffeine.body.contains("after 2"))
    }

    func testOvernightHasNoActivePhaseGuidance() {
        XCTAssertTrue(WindDownGuidanceLibrary.items(for: .overnight).isEmpty)
        XCTAssertNil(NightWatchGuidance.tip(for: .overnight, seed: UUID()))
    }

    func testFeaturedGuidanceIsStableForTheSameRun() {
        let seed = UUID(uuidString: "00000000-0000-0000-0000-000000000042")!

        XCTAssertEqual(
            WindDownGuidanceLibrary.featured(for: .windDown, seed: seed),
            WindDownGuidanceLibrary.featured(for: .windDown, seed: seed)
        )
    }

    func testHomeGuidancePrefersTheFirstSelectedEveningIdeaDeterministically() {
        let evening = [
            WindDownRoutineStep.suggested(.read, phase: .evening),
            WindDownRoutineStep.suggested(.journal, phase: .evening)
        ]
        let morning = [WindDownRoutineStep.suggested(.openCurtains, phase: .morning)]

        let first = WindDownGuidanceLibrary.homeGuidance(
            eveningRoutine: evening,
            morningRoutine: morning
        )
        let second = WindDownGuidanceLibrary.homeGuidance(
            eveningRoutine: evening,
            morningRoutine: morning
        )

        XCTAssertEqual(first?.id, "quiet-hour")
        XCTAssertEqual(first, second)
    }

    func testActiveGuidanceMatchesOnlyTheSelectedRoutinePhase() {
        let plan = NightWatchPlan(
            intendedBedtime: Date(timeIntervalSince1970: 10_000),
            wakeTime: Date(timeIntervalSince1970: 40_000),
            protectedUntil: Date(timeIntervalSince1970: 42_000),
            windDownMinutes: 30,
            morningQuietMinutes: 30,
            eveningActivity: .read,
            morningActivity: .openCurtains,
            eveningRoutine: [WindDownRoutineStep.suggested(.read, phase: .evening)],
            morningRoutine: [WindDownRoutineStep.suggested(.openCurtains, phase: .morning)]
        )

        XCTAssertEqual(
            WindDownGuidanceLibrary.activeGuidance(for: .windDown, plan: plan)?.id,
            "quiet-hour"
        )
        XCTAssertEqual(
            WindDownGuidanceLibrary.activeGuidance(for: .morningQuiet, plan: plan)?.id,
            "morning-light"
        )
        XCTAssertNil(WindDownGuidanceLibrary.activeGuidance(for: .overnight, plan: plan))
        XCTAssertNil(WindDownGuidanceLibrary.activeGuidance(for: .complete, plan: plan))
    }

    func testUnassociatedRoutinesProduceNoGuidance() {
        let evening = [WindDownRoutineStep.suggested(.prepareTomorrow, phase: .evening)]
        let morning = [WindDownRoutineStep.suggested(.breakfast, phase: .morning)]

        let selected = WindDownGuidanceLibrary.homeGuidance(
            eveningRoutine: evening,
            morningRoutine: morning
        )

        XCTAssertNil(selected)
    }

    func testPlacementReturnsAtMostOneItemAndDoesNotUseMealOrCaffeineByDefault() {
        let selected = WindDownGuidanceLibrary.homeGuidance(
            eveningRoutine: [WindDownRoutineStep.suggested(.read, phase: .evening)],
            morningRoutine: [WindDownRoutineStep.suggested(.openCurtains, phase: .morning)]
        )
        let placements = [selected].compactMap { $0 }

        XCTAssertLessThanOrEqual(placements.count, 1)
        XCTAssertFalse(placements.contains { $0.id == "leave-room-after-heavy-meal" })
        XCTAssertFalse(placements.contains { $0.id == "personal-caffeine-cutoff" })
    }

    func testGuidanceLibraryUsesStableContextGroupsAndSourceMetadata() throws {
        XCTAssertFalse(WindDownGuidanceLibrary.items(for: .evening).isEmpty)
        XCTAssertFalse(WindDownGuidanceLibrary.items(for: WindDownGuidanceGroup.morning).isEmpty)
        XCTAssertEqual(
            WindDownGuidanceLibrary.items(for: .phoneAway).map(\.id),
            ["phone-bed"]
        )
        let item = try XCTUnwrap(WindDownGuidanceLibrary.items.first { $0.id == "morning-light" })
        let source = try XCTUnwrap(WindDownGuidanceSourceRegistry.source(for: item.sourceIDs[0]))
        XCTAssertFalse(source.organization.isEmpty)
        XCTAssertNotNil(source.url)
        XCTAssertEqual(item.routineActivity, .openCurtains)
    }

    func testIdeasAndSourcesLibraryKeepsAllTopicAndSourceRecordsReachable() throws {
        XCTAssertEqual(WindDownGuidanceLibrary.items.count, 10)
        XCTAssertEqual(WindDownGuidanceTopic.allCases.count, 6)
        XCTAssertEqual(WindDownGuidanceSourceRegistry.sources.count, 7)
        XCTAssertEqual(
            Set(WindDownGuidanceTopic.allCases.flatMap(WindDownGuidanceLibrary.items(for:)).map(\.id)),
            Set(WindDownGuidanceLibrary.items.map(\.id))
        )
        XCTAssertEqual(
            WindDownGuidanceTopic.allCases.map { WindDownGuidanceLibrary.items(for: $0).count },
            [1, 4, 1, 2, 1, 1]
        )

        let external = WindDownGuidanceSourceRegistry.sources(of: .external)
        let internalNotes = WindDownGuidanceSourceRegistry.sources(of: .internalReference)
        XCTAssertEqual(external.count, 5)
        XCTAssertEqual(internalNotes.count, 2)
        XCTAssertEqual(Set(WindDownGuidanceSourceRegistry.sources.map(\.id)).count, 7)
        XCTAssertTrue(external.allSatisfy { $0.url != nil })
        XCTAssertTrue(internalNotes.allSatisfy { $0.url == nil })

        let aasm = try XCTUnwrap(WindDownGuidanceSourceRegistry.source(for: "aasm-cbt-i"))
        XCTAssertTrue(aasm.isBackgroundContext)
        XCTAssertTrue(WindDownGuidanceLibrary.items(referencingSourceID: aasm.id).isEmpty)
        XCTAssertEqual(
            WindDownGuidanceLibrary.items(referencingSourceID: "va-stimulus-control").map(\.id),
            ["rest-not-performance", "bed-as-cue"]
        )
    }

    func testGuidanceDismissalStoreIsInjectedAndHasCooldown() {
        let suiteName = "WindDownGuidanceTests.dismissal.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Expected defaults suite")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = WindDownGuidanceDismissalStore(defaults: defaults)
        let now = Date(timeIntervalSince1970: 10_000)
        store.dismiss("quiet-hour", at: now)
        XCTAssertTrue(store.isSuppressed("quiet-hour", at: now.addingTimeInterval(60)))
        XCTAssertFalse(store.isSuppressed("quiet-hour", at: now.addingTimeInterval(WindDownGuidanceDismissalStore.cooldown)))
    }

    func testBackgroundTimingIdeasHaveNoInventedRoutineMapping() throws {
        let meal = try XCTUnwrap(WindDownGuidanceLibrary.items.first { $0.id == "leave-room-after-heavy-meal" })
        let caffeine = try XCTUnwrap(WindDownGuidanceLibrary.items.first { $0.id == "personal-caffeine-cutoff" })
        XCTAssertNil(meal.routineActivity)
        XCTAssertNil(caffeine.routineActivity)
    }

    func testRoutineMutationPersistsTheSelectedGuidanceAndTitle() throws {
        let item = try XCTUnwrap(WindDownGuidanceLibrary.items.first { $0.id == "morning-light" })
        var steps = [WindDownRoutineStep.suggested(.makeBed, phase: .morning)]

        XCTAssertEqual(WindDownGuidanceRoutineMutation.add(item, to: &steps), .added)
        XCTAssertEqual(steps.last?.guidanceID, item.id)
        XCTAssertEqual(steps.last?.activity, .openCurtains)
        XCTAssertEqual(steps.last?.title, "Open the curtains")
    }

    func testRoutineMutationDoesNotCallDifferentIdeaTheSameActivityAlreadyAdded() throws {
        let item = try XCTUnwrap(WindDownGuidanceLibrary.items.first { $0.id == "morning-light" })
        var steps = [WindDownRoutineStep(
            phase: .morning,
            kind: .suggestion,
            activity: .openCurtains,
            guidanceID: "different-idea"
        )]
        let original = steps

        XCTAssertEqual(WindDownGuidanceRoutineMutation.add(item, to: &steps), .unavailable)
        XCTAssertEqual(steps, original)
    }

    func testGuidanceDisplayPolicyShowsOncePerContextAndSpacesLaterOpportunities() {
        let suiteName = "WindDownGuidanceTests.display.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Expected defaults suite")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = WindDownGuidanceDisplayStore(defaults: defaults)
        let item = WindDownGuidanceLibrary.items[1]
        let now = Date(timeIntervalSince1970: 10_000)
        let context = WindDownGuidanceDisplayPolicy.contextID(
            for: item,
            eveningRoutine: [],
            morningRoutine: [],
            at: now
        )
        XCTAssertTrue(store.shouldDisplay(itemID: item.id, contextID: context, at: now))
        store.markShown(item.id, contextID: context, at: now)
        XCTAssertFalse(store.shouldDisplay(itemID: item.id, contextID: context, at: now.addingTimeInterval(7 * 86_400)))

        let laterContext = context + "|changed-routine"
        XCTAssertFalse(store.shouldDisplay(
            itemID: item.id,
            contextID: laterContext,
            at: now.addingTimeInterval(WindDownGuidanceDisplayStore.minimumRepeatInterval - 1)
        ))
        XCTAssertTrue(store.shouldDisplay(
            itemID: item.id,
            contextID: laterContext,
            at: now.addingTimeInterval(WindDownGuidanceDisplayStore.minimumRepeatInterval)
        ))
    }
}
