import Foundation

struct ProximityClassifierContext {
    var now: Date
    var watchReachable: Bool
    var nearbySupported: Bool
    var demoMode: Bool
    var currentRunState: FocusRunState
    var plannedEndAt: Date?
    var phoneAwayValidated: Bool
}

struct ProximityClassifier {
    var thresholds: ThresholdProfile

    init(thresholds: ThresholdProfile = .defaults) {
        self.thresholds = thresholds
    }

    func classify(readings: [ProximityReading], previous: ProximityState?, context: ProximityClassifierContext) -> ProximityState {
        if context.demoMode, let latest = readings.last {
            let bucket = bucket(for: latest.distanceMeters, readings: readings, allowSustainedOtherRoom: true)
            return makeState(bucket: bucket == .probablyOtherRoom ? .demo : bucket, reading: latest, confidence: .medium, detail: "Local simulation is driving a shepherding run.")
        }

        guard context.nearbySupported else {
            return ProximityState(bucket: .unsupported, distanceMeters: nil, confidence: .low, source: .fallback, lastUpdated: context.now, statusText: ProximityBucket.unsupported.label, detailText: "Nearby Interaction is unavailable on this setup.")
        }

        guard let latest = readings.last else {
            let fallbackBucket: ProximityBucket = context.watchReachable ? .waitingForDistance : .signalLost
            return ProximityState(bucket: fallbackBucket, distanceMeters: nil, confidence: .low, source: .watchConnectivity, lastUpdated: context.now, statusText: fallbackBucket.label, detailText: "Waiting for fresh distance readings.")
        }

        if context.now.timeIntervalSince(latest.timestamp) > thresholds.staleAfterSeconds {
            return ProximityState(bucket: .signalLost, distanceMeters: latest.distanceMeters, confidence: .low, source: latest.source, lastUpdated: latest.timestamp, statusText: ProximityBucket.signalLost.label, detailText: "The latest room check is stale.")
        }

        let rawBucket = bucket(for: latest.distanceMeters, readings: readings, allowSustainedOtherRoom: sustainedOtherRoom(readings))
        let smoothed = smooth(rawBucket: rawBucket, previous: previous?.bucket, readings: readings)
        let confidence = confidence(for: smoothed, readings: readings, context: context)
        return makeState(bucket: smoothed, reading: latest, confidence: confidence, detail: detail(for: smoothed, confidence: confidence))
    }

    func shouldValidatePhoneAway(readings: [ProximityReading], state: ProximityState) -> Bool {
        state.bucket == .probablyOtherRoom || state.bucket == .demo || sustainedOtherRoom(readings)
    }

    func shouldWarnPhoneTooClose(readings: [ProximityReading], state: ProximityState) -> Bool {
        let close = readings.suffix(thresholds.sustainedSamples).filter { ($0.distanceMeters ?? .greatestFiniteMagnitude) < thresholds.sameRoomMaxMeters }
        return close.count >= thresholds.sustainedSamples
    }

    private func bucket(for distance: Double?, readings: [ProximityReading], allowSustainedOtherRoom: Bool) -> ProximityBucket {
        guard let distance else { return .waitingForDistance }
        if distance < thresholds.withYouMaxMeters { return .withYou }
        if distance < thresholds.sameRoomMaxMeters { return .sameRoom }
        if distance < thresholds.otherRoomMinMeters { return .doorway }
        return allowSustainedOtherRoom ? .probablyOtherRoom : .doorway
    }

    private func sustainedOtherRoom(_ readings: [ProximityReading]) -> Bool {
        let required = max(1, thresholds.sustainedSamples)
        let recent = readings.suffix(required)
        guard recent.count == required else { return false }
        return recent.allSatisfy { ($0.distanceMeters ?? 0) >= thresholds.otherRoomMinMeters }
    }

    private func smooth(rawBucket: ProximityBucket, previous: ProximityBucket?, readings: [ProximityReading]) -> ProximityBucket {
        guard let previous else { return rawBucket }
        if rawBucket == .probablyOtherRoom || rawBucket == .withYou { return rawBucket }
        if rawBucket == .waitingForDistance { return .waitingForDistance }
        if previous == .probablyOtherRoom, rawBucket == .doorway { return .probablyOtherRoom }
        if previous == .withYou, rawBucket == .sameRoom, readings.count < thresholds.sustainedSamples { return .withYou }
        return rawBucket
    }

    private func confidence(for currentBucket: ProximityBucket, readings: [ProximityReading], context: ProximityClassifierContext) -> ProximityConfidence {
        guard let latest = readings.last else { return .low }
        if context.demoMode { return .medium }
        if context.now.timeIntervalSince(latest.timestamp) > thresholds.staleAfterSeconds { return .low }
        if latest.distanceMeters == nil { return context.watchReachable ? .low : .low }
        let stableCount = readings.suffix(thresholds.sustainedSamples).filter { reading in
            bucket(for: reading.distanceMeters, readings: readings, allowSustainedOtherRoom: true) == currentBucket
        }.count
        if latest.source == .nearbyInteraction && stableCount >= thresholds.sustainedSamples { return .high }
        if currentBucket == .doorway || context.currentRunState == .warningPhoneTooClose { return .medium }
        return .medium
    }

    private func makeState(bucket: ProximityBucket, reading: ProximityReading, confidence: ProximityConfidence, detail: String) -> ProximityState {
        ProximityState(bucket: bucket, distanceMeters: reading.distanceMeters, confidence: confidence, source: reading.source, lastUpdated: reading.timestamp, statusText: bucket.label, detailText: detail)
    }

    private func detail(for bucket: ProximityBucket, confidence: ProximityConfidence) -> String {
        switch bucket {
        case .waitingForDistance: return "Ollie is waiting for a live distance check."
        case .withYou: return "Ollie can tell the phone is still close."
        case .sameRoom: return "The phone seems nearby. Keep moving toward the pasture."
        case .doorway: return "The phone is drifting away; Ollie is watching for a stable trail."
        case .probablyOtherRoom: return "Sustained readings say the phone has reached its resting place."
        case .signalLost: return "The trail went quiet. Ollie will wait before judging the run."
        case .unsupported: return "Phone distance is unavailable on this setup."
        case .demo: return "Local simulation is driving a reliable shepherding run."
        }
    }
}
