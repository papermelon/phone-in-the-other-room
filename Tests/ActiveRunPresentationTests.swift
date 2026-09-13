import XCTest

final class ActiveRunPresentationTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_001_000)
    private var end: Date {
        now.addingTimeInterval(30 * 60)
    }

    func testAdditionalQuietMapsToQuietOnlyPresentation() {
        let presentation = ActiveRunPresentation(
            role: .additionalQuiet,
            phase: .windDown,
            planEndDate: end,
            nextTransitionDate: end,
            runID: UUID(),
            now: now
        )

        XCTAssertEqual(presentation.eyebrow, "PHONE AWAY")
        XCTAssertEqual(presentation.headline, "Phone Away timer is running.")
        XCTAssertEqual(presentation.transitionCaption, "Ends at \(end.formatted(date: .omitted, time: .shortened))")
        XCTAssertEqual(presentation.returnBarTitle, "Phone Away")
        XCTAssertEqual(
            presentation.timerAccessibilityLabel(remainingSeconds: 30 * 60),
            "30 minutes until Phone Away ends"
        )
        XCTAssertNil(presentation.guidanceTip())

        let copy = [
            presentation.eyebrow,
            presentation.headline,
            presentation.subheadline,
            presentation.transitionCaption,
            presentation.phaseStatusText,
            presentation.returnBarTitle,
            presentation.returnBarAccessibilityHint,
            presentation.exit.actionTitle,
            presentation.exit.confirmationTitle,
            presentation.exit.confirmationBody,
            presentation.exit.cancelTitle,
            presentation.exit.confirmTitle
        ].joined(separator: " ").lowercased()
        for forbidden in ["bedtime", "sleep time", "morning quiet", "protected-night", "next wind down step", "tucked away"] {
            XCTAssertFalse(copy.contains(forbidden), "Unexpected Phone Break copy: \(forbidden)")
        }
    }

    func testPrimaryPhaseMappingsStayDistinct() {
        let cases: [(NightWatchPhase, String, String)] = [
            (.windDown, "WIND DOWN · EVENING", "Bedtime at"),
            (.overnight, "WIND DOWN · OVERNIGHT", "Screen-Free Morning begins at"),
            (.morningQuiet, "SCREEN-FREE MORNING", "Screen-Free Morning ends at"),
            (.complete, "WIND DOWN TIMER ENDED", "Wind Down timer ended")
        ]

        for (phase, eyebrow, captionPrefix) in cases {
            let presentation = ActiveRunPresentation(
                role: .primarySleepBookend,
                phase: phase,
                planEndDate: end,
                nextTransitionDate: phase == .complete ? nil : end,
                now: now
            )
            XCTAssertEqual(presentation.eyebrow, eyebrow)
            XCTAssertTrue(presentation.transitionCaption.hasPrefix(captionPrefix))
            XCTAssertEqual(presentation.returnBarTitle, "Wind Down")
        }
    }

    func testPrimaryActiveRunCopyDoesNotIntroducePhoneAwayProgress() {
        let presentation = ActiveRunPresentation(
            role: .primarySleepBookend,
            phase: .overnight,
            planEndDate: end,
            nextTransitionDate: end,
            now: now
        )

        let copy = [
            presentation.eyebrow,
            presentation.headline,
            presentation.subheadline,
            presentation.transitionCaption,
            presentation.phaseStatusText,
            presentation.returnBarAccessibilityHint,
            presentation.timerAccessibilityLabel(remainingSeconds: 30 * 60)
        ]
        .joined(separator: " ")
        .lowercased()

        XCTAssertFalse(copy.contains("phone away"))
        XCTAssertFalse(copy.contains("bonus search"))
        XCTAssertFalse(copy.contains("extra search progress"))
        XCTAssertTrue(copy.contains("wind down"))
    }

    func testShieldingOutcomeMapsToTypedPresentationState() {
        XCTAssertEqual(
            ActiveRunShieldingState.from(.disabled),
            .notRequested
        )
        XCTAssertEqual(
            ActiveRunShieldingState.from(.cleared),
            .notRequested
        )
        XCTAssertEqual(
            ActiveRunShieldingState.from(.scheduled),
            .scheduled
        )
        XCTAssertEqual(
            ActiveRunShieldingState.from(.applied),
            .active
        )
        XCTAssertEqual(
            ActiveRunShieldingState.from(.noSelection),
            .failed(.noSelection)
        )
        XCTAssertEqual(
            ActiveRunShieldingState.from(.failed("monitoring")),
            .failed(.monitoring)
        )
        XCTAssertEqual(
            ActiveRunShieldingState.from(.failed("unavailable")),
            .failed(.unavailable)
        )
        XCTAssertEqual(
            ActiveRunShieldingState.from(.failed("future-reason")),
            .failed(.other)
        )
    }

    func testShieldingBannerMapsEveryStatusAndRetryOnlyForMonitoringFailure() {
        let states: [(ActiveRunShieldingState, String?, String?)] = [
            (.notRequested, nil, nil),
            (.scheduled, "Selected-app limits are scheduled to end at", nil),
            (.active, "Selected-app limits are active now and scheduled to end at", nil),
            (.failed(.noSelection), "Selected-app limits did not start. The Phone Away timer continues; repair protection before another start.", nil),
            (.failed(.unavailable), "Selected-app limits did not stay active. The Phone Away timer continues; repair protection before another start.", nil),
            (.failed(.other), "Selected-app limits did not stay active. The Phone Away timer continues; repair protection before another start.", nil),
            (.failed(.monitoring), "Selected-app limits did not stay active. The Phone Away timer continues; repair protection before another start.", "Try app limits again")
        ]

        for (state, message, retryTitle) in states {
            let presentation = ActiveRunPresentation(
                role: .additionalQuiet,
                phase: .windDown,
                planEndDate: end,
                shieldingState: state,
                now: now
            )
            XCTAssertEqual(presentation.shieldingBanner?.message, message.map {
                $0.hasSuffix(".") ? $0 : "\($0) \(end.formatted(date: .omitted, time: .shortened))."
            })
            XCTAssertEqual(presentation.shieldingBanner?.retryTitle, retryTitle)
        }
    }

    func testShieldingUsesActualPlanEndDateForPrimaryAndAdditional() {
        let primary = ActiveRunPresentation(
            role: .primarySleepBookend,
            phase: .overnight,
            planEndDate: end,
            shieldingState: .active,
            now: now
        )
        let additional = ActiveRunPresentation(
            role: .additionalQuiet,
            phase: .windDown,
            planEndDate: end,
            shieldingState: .active,
            now: now
        )
        let endTime = end.formatted(date: .omitted, time: .shortened)

        XCTAssertEqual(primary.shieldingBanner?.message, "Selected-app limits are active now and scheduled to end at \(endTime).")
        XCTAssertEqual(additional.shieldingBanner?.message, "Selected-app limits are active now and scheduled to end at \(endTime).")
    }

    func testExitPresentationMapsPrimaryAndAdditionalActions() {
        let additional = ActiveRunPresentation(
            role: .additionalQuiet,
            phase: .windDown,
            planEndDate: end,
            now: now
        ).exit
        XCTAssertEqual(additional.actionTitle, "End Phone Away early")
        XCTAssertEqual(additional.confirmationTitle, "End Phone Away early?")
        XCTAssertEqual(additional.confirmationBody, "This ends the timer and lifts selected-app limits.")
        XCTAssertEqual(additional.cancelTitle, "Keep Phone Away running")
        XCTAssertEqual(additional.confirmTitle, "End Phone Away")

        let primary = ActiveRunPresentation(
            role: .primarySleepBookend,
            phase: .overnight,
            planEndDate: end,
            now: now
        ).exit
        XCTAssertEqual(primary.actionTitle, "End Wind Down early")
        XCTAssertEqual(primary.confirmationTitle, "End Wind Down early?")
        XCTAssertEqual(primary.cancelTitle, "Keep Wind Down running")
        XCTAssertEqual(primary.confirmTitle, "End Wind Down")
    }

    func testNFCAndEmergencyExitCopyStayDistinct() {
        let phoneAway = ActiveRunPresentation(
            role: .additionalQuiet,
            phase: .windDown,
            planEndDate: end,
            now: now
        )
        XCTAssertEqual(phoneAway.nfcExitActionTitle, "Tap tag to end Phone Away")
        XCTAssertEqual(phoneAway.emergencyExit.actionTitle, "End Phone Away without the tag")
        XCTAssertTrue(phoneAway.emergencyExit.confirmationBody.contains("without the registered tag"))

        let windDown = ActiveRunPresentation(
            role: .primarySleepBookend,
            phase: .overnight,
            planEndDate: end,
            now: now
        )
        XCTAssertEqual(windDown.nfcExitActionTitle, "Tap tag to end Wind Down")
        XCTAssertEqual(windDown.emergencyExit.actionTitle, "End Wind Down without the tag")
        XCTAssertTrue(windDown.emergencyExit.confirmationBody.contains("without the registered tag"))
    }

    func testTerminalCopyIsRoleAwareAndLimitedToTimerFacts() {
        let windDown = RunTerminalPresentation(
            role: .primarySleepBookend,
            completedSuccessfully: true,
            elapsedSeconds: 8.5 * 60 * 60
        )
        let phoneAway = RunTerminalPresentation(
            role: .additionalQuiet,
            completedSuccessfully: false,
            elapsedSeconds: 12 * 60
        )

        XCTAssertEqual(windDown.eyebrow, "WIND DOWN TIMER ENDED")
        XCTAssertEqual(windDown.timerSummary, "8h 30m on the Wind Down timer.")
        XCTAssertEqual(phoneAway.eyebrow, "PHONE AWAY TIME SAVED")
        XCTAssertEqual(phoneAway.timerSummary, "12 min on the Phone Away timer.")

        let copy = [
            windDown.headline,
            windDown.timerSummary,
            windDown.accessibilityLabel,
            phoneAway.headline,
            phoneAway.timerSummary,
            phoneAway.accessibilityLabel
        ].joined(separator: " ").lowercased()
        for forbidden in ["tucked", "slept", "sleep", "screen-free", "search journal", "sheep"] {
            XCTAssertFalse(copy.contains(forbidden), "Unexpected terminal claim: \(forbidden)")
        }
    }
}

final class SessionExitAuthorizationTests: XCTestCase {
    func testNFCWindDownNormalEndRequiresAndRecordsAuthenticatedTag() {
        let run = makeRun(role: .primarySleepBookend, guardKind: .nfcTag)
        let terminalRun = SessionExitTransition.ending(
            run,
            requestedReason: .nfcTagAuthenticated,
            at: Date(timeIntervalSince1970: 2_000)
        )

        XCTAssertEqual(terminalRun?.state, .endedEarly)
        XCTAssertEqual(terminalRun?.endedEarlyReason, .nfcTagAuthenticated)
    }

    func testNFCPhoneAwayNormalEndRequiresAndRecordsAuthenticatedTag() {
        let run = makeRun(role: .additionalQuiet, guardKind: .nfcTag)
        let terminalRun = SessionExitTransition.ending(
            run,
            requestedReason: .nfcTagAuthenticated,
            at: Date(timeIntervalSince1970: 2_000)
        )

        XCTAssertEqual(terminalRun?.state, .endedEarly)
        XCTAssertEqual(terminalRun?.endedEarlyReason, .nfcTagAuthenticated)
    }

    func testHonorTimerAllowsDirectUserEnd() {
        let run = makeRun(role: .additionalQuiet, guardKind: .honorTimer)
        let terminalRun = SessionExitTransition.ending(
            run,
            requestedReason: .userEnded,
            at: Date(timeIntervalSince1970: 2_000)
        )

        XCTAssertEqual(terminalRun?.state, .endedEarly)
        XCTAssertEqual(terminalRun?.endedEarlyReason, .userEnded)
    }

    func testWrongCancelledAndUnavailableNFCScansLeaveExitUnauthorized() {
        let attempts: [(SessionExitAttempt, SessionExitRejection)] = [
            (.mismatchedNFCTag, .mismatchedNFCTag),
            (.cancelledNFCScan, .cancelledNFCScan),
            (.unavailableNFCScan, .unavailableNFCScan)
        ]

        for (attempt, rejection) in attempts {
            XCTAssertEqual(
                SessionExitAuthorizationPolicy.authorization(
                    for: .nfcTag,
                    attempt: attempt
                ),
                .rejected(rejection)
            )
        }
    }

    func testMissingRegisteredTagDoesNotDowngradeToDirectEnd() {
        XCTAssertEqual(
            SessionExitAuthorizationPolicy.authorization(
                for: .nfcTag,
                attempt: .missingRegisteredNFCTag
            ),
            .rejected(.missingRegisteredNFCTag)
        )
    }

    func testCoordinatorPolicyRejectsUnverifiedUserEndedOnNFC() {
        let run = makeRun(role: .primarySleepBookend, guardKind: .nfcTag)
        let terminalRun = SessionExitTransition.ending(
            run,
            requestedReason: .userEnded,
            at: Date(timeIntervalSince1970: 2_000)
        )

        XCTAssertNil(terminalRun)
        XCTAssertEqual(run.state, .running)
        XCTAssertNil(run.endedAt)
        XCTAssertNil(run.endedEarlyReason)
    }

    func testAuthenticatedTagReasonPersists() throws {
        let authenticated = try XCTUnwrap(
            SessionExitAuthorizationPolicy.authorization(
                for: .nfcTag,
                attempt: .authenticatedNFCTag
            ).reason
        )
        let authenticatedRun = try XCTUnwrap(
            SessionExitTransition.ending(
                makeRun(role: .primarySleepBookend, guardKind: .nfcTag),
                requestedReason: authenticated,
                at: Date(timeIntervalSince1970: 2_000)
            )
        )
        XCTAssertEqual(authenticatedRun.endedEarlyReason, .nfcTagAuthenticated)

    }

    func testRawEmergencyBypassIsRejectedForNFC() {
        XCTAssertEqual(
            SessionExitAuthorizationPolicy.authorization(
                for: .nfcTag,
                attempt: .emergencyBypass
            ),
            .rejected(.emergencyChallengeRequired)
        )
        XCTAssertEqual(
            SessionExitTransition.ending(
                makeRun(role: .primarySleepBookend, guardKind: .nfcTag),
                requestedReason: .emergencyBypass,
                at: Date(timeIntervalSince1970: 2_000)
            ),
            nil
        )
    }

    func testEmergencyChallengeRequiresReasonTwiceAndConsumesOnlyOnce() {
        let runID = UUID()
        var machine = EmergencyExitChallengeMachine()
        let challenge = machine.begin(for: runID)
        XCTAssertEqual(challenge.activeRunID, runID)
        XCTAssertFalse(machine.submit("   ", for: runID))
        XCTAssertEqual(machine.challenge?.stage, .enterWord)
        XCTAssertTrue(machine.submit("Reply to a message", for: runID))
        XCTAssertEqual(machine.challenge?.stage, .readyToConfirm)
        XCTAssertFalse(machine.submit("Something else", for: runID))
        XCTAssertTrue(machine.submit("  reply to a message  ", for: runID))
        XCTAssertTrue(machine.consumeConfirmation(for: runID))
        XCTAssertFalse(machine.consumeConfirmation(for: runID))
        XCTAssertNil(machine.challenge)
    }

    func testEmergencyChallengeCancelsAndInvalidatesOnRunMismatch() {
        var machine = EmergencyExitChallengeMachine()
        let runID = UUID()
        _ = machine.begin(for: runID)
        XCTAssertFalse(machine.submit("END", for: UUID()))
        XCTAssertNil(machine.challenge)
        _ = machine.begin(for: runID)
        machine.cancel()
        XCTAssertNil(machine.challenge)
        XCTAssertFalse(machine.consumeConfirmation(for: runID))
    }

    func testEmergencyChallengeIsEphemeralByConstruction() throws {
        let challenge = EmergencyExitChallenge(activeRunID: UUID())
        XCTAssertEqual(challenge.stage, .enterWord)
        XCTAssertNil(Mirror(reflecting: challenge).children.first { $0.label == "typedWord" })
    }

    func testEmergencyExitPresentationKeepsPrimaryNFCActionAndExplainsTagBypass() {
        let presentation = ActiveRunPresentation(
            role: .additionalQuiet,
            phase: .windDown,
            planEndDate: Date(timeIntervalSince1970: 2_000),
            now: Date(timeIntervalSince1970: 1_000)
        )
        XCTAssertEqual(presentation.nfcExitActionTitle, "Tap tag to end Phone Away")
        XCTAssertTrue(presentation.emergencyExit.confirmationBody.contains("without the registered tag"))
    }

    func testRawEmergencyBypassIsRejectedForHonorTimerAndWatch() {
        XCTAssertEqual(
            SessionExitAuthorizationPolicy.authorization(
                for: .honorTimer,
                requestedReason: .emergencyBypass
            ),
            .rejected(.emergencyChallengeRequired)
        )
        XCTAssertNil(
            SessionExitTransition.ending(
                makeRun(role: .additionalQuiet, guardKind: .honorTimer),
                requestedReason: .emergencyBypass,
                at: Date(timeIntervalSince1970: 2_000)
            )
        )
        XCTAssertNil(
            SessionExitTransition.ending(
                makeRun(role: .additionalQuiet, guardKind: .nfcTag),
                requestedReason: .emergencyBypass,
                source: .watch,
                at: Date(timeIntervalSince1970: 2_000)
            )
        )
    }


    func testWatchCannotBypassNFCForAnyUserExitReason() {
        for reason in [
            EarlyEndReason.userEnded,
            .nfcTagAuthenticated,
            .emergencyBypass
        ] {
            let run = makeRun(role: .additionalQuiet, guardKind: .nfcTag)
            XCTAssertNil(
                SessionExitTransition.ending(
                    run,
                    requestedReason: reason,
                    source: .watch,
                    at: Date(timeIntervalSince1970: 2_000)
                )
            )
            XCTAssertEqual(run.state, .running)
        }
    }

    private func makeRun(
        role: WindDownOccurrenceRole,
        guardKind: SessionGuardKind
    ) -> FocusRun {
        let start = Date(timeIntervalSince1970: 1_000)
        let plan = NightWatchPlan(
            intendedBedtime: start.addingTimeInterval(30 * 60),
            wakeTime: start.addingTimeInterval(8 * 60 * 60),
            protectedUntil: start.addingTimeInterval(8.5 * 60 * 60),
            windDownMinutes: 30,
            morningQuietMinutes: 30,
            eveningActivity: .read,
            morningActivity: .openCurtains,
            role: role
        )
        return FocusRun(
            plannedDurationSeconds: plan.protectedUntil.timeIntervalSince(start),
            startedAt: start,
            state: .running,
            guardKind: guardKind,
            nightWatchPlan: plan
        )
    }
}
