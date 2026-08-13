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

        XCTAssertEqual(presentation.eyebrow, "PHONE BREAK")
        XCTAssertEqual(presentation.headline, "A little room away from the screen.")
        XCTAssertEqual(presentation.transitionCaption, "Ends at \(end.formatted(date: .omitted, time: .shortened))")
        XCTAssertEqual(presentation.returnBarTitle, "Phone Break")
        XCTAssertEqual(
            presentation.timerAccessibilityLabel(remainingSeconds: 30 * 60),
            "30 minutes until Phone Break ends"
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
        for forbidden in ["bedtime", "sleep time", "morning quiet", "protected-night", "next wind down step"] {
            XCTAssertFalse(copy.contains(forbidden), "Unexpected Phone Break copy: \(forbidden)")
        }
    }

    func testPrimaryPhaseMappingsStayDistinct() {
        let cases: [(NightWatchPhase, String, String)] = [
            (.windDown, "PHONE-FREE WIND-DOWN", "Bedtime at"),
            (.overnight, "SLEEP TIME", "Phone-free morning begins at"),
            (.morningQuiet, "PHONE-FREE MORNING", "Your phone wakes at"),
            (.complete, "NIGHT COMPLETE", "Wind Down is complete")
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
            (.scheduled, "Selected apps will be limited until", nil),
            (.active, "Selected apps are limited until", nil),
            (.failed(.noSelection), "App limits didn’t start. Your Phone Break timer is still running.", nil),
            (.failed(.unavailable), "App limits didn’t start. Your Phone Break timer is still running.", nil),
            (.failed(.other), "App limits didn’t start. Your Phone Break timer is still running.", nil),
            (.failed(.monitoring), "App limits didn’t start. Your Phone Break timer is still running.", "Try app limits again")
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

        XCTAssertEqual(primary.shieldingBanner?.message, "Selected apps are limited until \(endTime).")
        XCTAssertEqual(additional.shieldingBanner?.message, "Selected apps are limited until \(endTime).")
    }

    func testExitPresentationMapsPrimaryAndAdditionalActions() {
        let additional = ActiveRunPresentation(
            role: .additionalQuiet,
            phase: .windDown,
            planEndDate: end,
            now: now
        ).exit
        XCTAssertEqual(additional.actionTitle, "End Phone Break early")
        XCTAssertEqual(additional.confirmationTitle, "End Phone Break early?")
        XCTAssertEqual(additional.confirmationBody, "This ends the timer and removes any app limits.")
        XCTAssertEqual(additional.cancelTitle, "Keep Phone Break running")
        XCTAssertEqual(additional.confirmTitle, "End Phone Break")

        let primary = ActiveRunPresentation(
            role: .primarySleepBookend,
            phase: .overnight,
            planEndDate: end,
            now: now
        ).exit
        XCTAssertEqual(primary.actionTitle, "End Wind Down early")
        XCTAssertEqual(primary.confirmationTitle, "End Wind Down early?")
        XCTAssertEqual(primary.cancelTitle, "Keep Wind Down running")
        XCTAssertEqual(primary.confirmTitle, "Use emergency exit")
    }
}
