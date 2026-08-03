import Foundation
import UIKit

@MainActor
extension FocusSessionCoordinator {
    func startWatchPlacement() {
        guard let run,
              run.guardKind == .watchPlacement,
              run.placementStatus == .awaitingConfirmation else {
            return
        }
        stopWatchPlacement()
        proximityState = ProximityState(
            bucket: .waitingForDistance,
            distanceMeters: nil,
            confidence: .low,
            source: .watchConnectivity,
            lastUpdated: Date(),
            statusText: "Ollie is checking the walk",
            detailText: "Bring the phone with you, then leave it where it will rest."
        )
        ollieMessage = "Ollie is watching the phone head away."
        watch.send(WatchMessage(type: .distanceCheckRequest, run: run, proximity: proximityState))
        placementTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await self.nearby.start()
            guard self.nearby.isSupported else {
                self.markWatchPlacementUnavailable()
                return
            }
            self.sendNearbyToken()
            for await reading in self.nearby.readings {
                guard !Task.isCancelled else { return }
                self.processPlacementReading(reading)
            }
        }
        placementTimeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled else { return }
            self?.markWatchPlacementUnavailable()
        }
#if DEBUG
        energyLogger.debug("Watch placement burst started timeoutSeconds=30")
#endif
    }

    func processPlacementReading(_ reading: ProximityReading) {
        guard var run,
              run.guardKind == .watchPlacement,
              run.placementStatus == .awaitingConfirmation else {
            return
        }
        run.proximityHistory.append(reading)
        run.proximityHistory = Array(run.proximityHistory.suffix(6))
        proximityState = ProximityState(
            bucket: reading.distanceMeters == nil ? .waitingForDistance : .doorway,
            distanceMeters: reading.distanceMeters,
            confidence: reading.confidence,
            source: reading.source,
            lastUpdated: reading.timestamp,
            statusText: "Ollie is checking the walk",
            detailText: "A short placement check is all Ollie needs."
        )
        if watchPlacementLooksAway(run.proximityHistory) {
            confirmPlacement(&run, note: "Watch saw the phone move away")
        } else {
            self.run = run
        }
    }

    private func watchPlacementLooksAway(_ readings: [ProximityReading]) -> Bool {
        let distances = readings.compactMap(\.distanceMeters)
        guard distances.count >= 2,
              let first = distances.first,
              let last = distances.last else {
            return false
        }
        return last >= 2.5 && last - first >= 0.75
    }

    func confirmPlacement(_ run: inout FocusRun, note: String) {
        run.placementStatus = .confirmed
        run.placementEvidence = PlacementEvidence(
            guardKind: run.guardKind,
            confirmedAt: Date(),
            note: note
        )
        run.phoneAwayValidatedAt = Date()
        run.state = .running
        self.run = run
        proximityState = ProximityState(
            bucket: .probablyOtherRoom,
            distanceMeters: run.proximityHistory.last?.distanceMeters,
            confidence: .medium,
            source: .nearbyInteraction,
            lastUpdated: Date(),
            statusText: "Phone is resting away",
            detailText: "Ollie finished the short placement check."
        )
        ollieMessage = "Ollie saw the phone head out. The quiet is now settled."
        addEvent("Phone placement confirmed.", severity: .success)
        persistActiveRun()
        reconcileShielding(for: run)
        stopWatchPlacement()
        UIApplication.shared.isIdleTimerDisabled = false
        watch.send(WatchMessage(type: .focusRunStateUpdate, run: run, proximity: proximityState))
        if Date() >= run.plannedEndAt {
            reconcileSession()
        }
    }

    private func markWatchPlacementUnavailable() {
        guard var run,
              run.guardKind == .watchPlacement,
              run.placementStatus == .awaitingConfirmation else {
            return
        }
        run.placementStatus = .unavailable
        run.state = .running
        self.run = run
        ollieMessage = "The Watch check can rest. Ollie will keep the timer warm."
        addEvent("Watch placement unavailable; timer continued.")
        persistActiveRun()
        reconcileShielding(for: run)
        stopWatchPlacement()
        UIApplication.shared.isIdleTimerDisabled = false
        if Date() >= run.plannedEndAt {
            reconcileSession()
        }
    }

    func stopWatchPlacement() {
        let hadActiveResources = placementTask != nil
            || placementTimeoutTask != nil
            || nearby.isRunning
        placementTask?.cancel()
        placementTask = nil
        placementTimeoutTask?.cancel()
        placementTimeoutTask = nil
        nearby.stop()
        pairedWatchTokenData = nil
        watch.send(
            WatchMessage(
                type: .distanceCheckEnded,
                run: run,
                proximity: proximityState
            )
        )
#if DEBUG
        if hadActiveResources {
            energyLogger.debug("Watch placement burst stopped")
        }
#endif
    }

    func receiveNearbyToken(_ tokenData: Data?) {
        guard let tokenData, tokenData != pairedWatchTokenData else { return }
        pairedWatchTokenData = tokenData
        nearby.run(withTokenData: tokenData)
        watch.send(
            WatchMessage(
                type: .nearbyDiscoveryTokenAcknowledged,
                run: run,
                proximity: proximityState,
                tokenData: tokenData
            )
        )
    }

    private func sendNearbyToken() {
        guard let tokenData = nearby.discoveryTokenData() else { return }
        watch.send(
            WatchMessage(
                type: .nearbyDiscoveryToken,
                run: run,
                proximity: proximityState,
                tokenData: tokenData
            )
        )
    }
}
