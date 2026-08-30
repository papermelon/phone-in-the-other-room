import Foundation

/// Local request history is useful for deciding whether to offer Apple's prompt,
/// but it is never treated as HealthKit read authorization.
enum HealthSleepLocalRequestState: Equatable {
    case notRequested
    case requested
    case failed
}

struct HealthSleepConnectionObservation: Equatable {
    var isAvailable: Bool
    var localRequestState: HealthSleepLocalRequestState
    var isRequestInFlight: Bool
    var isQueryInFlight: Bool
    var latestSampleDate: Date?
    var lastCheckedAt: Date?
    var lastQueryError: String?

    init(
        isAvailable: Bool,
        localRequestState: HealthSleepLocalRequestState,
        isRequestInFlight: Bool = false,
        isQueryInFlight: Bool = false,
        latestSampleDate: Date? = nil,
        lastCheckedAt: Date? = nil,
        lastQueryError: String? = nil
    ) {
        self.isAvailable = isAvailable
        self.localRequestState = localRequestState
        self.isRequestInFlight = isRequestInFlight
        self.isQueryInFlight = isQueryInFlight
        self.latestSampleDate = latestSampleDate
        self.lastCheckedAt = lastCheckedAt
        self.lastQueryError = lastQueryError
    }
}

enum HealthSleepConnectionPresentation: Equatable {
    case unavailable
    case connect
    case checking(cachedSampleDate: Date?)
    case dataAvailable(sampleDate: Date, checkedAt: Date)
    case noData(checkedAt: Date)
    case staleData(sampleDate: Date?, checkedAt: Date?, error: String)

    static func resolve(_ observation: HealthSleepConnectionObservation) -> Self {
        guard observation.isAvailable else { return .unavailable }

        if observation.isRequestInFlight || observation.isQueryInFlight {
            return .checking(cachedSampleDate: observation.latestSampleDate)
        }

        if let error = observation.lastQueryError {
            return .staleData(
                sampleDate: observation.latestSampleDate,
                checkedAt: observation.lastCheckedAt,
                error: error
            )
        }

        if let sampleDate = observation.latestSampleDate,
           let checkedAt = observation.lastCheckedAt {
            return .dataAvailable(sampleDate: sampleDate, checkedAt: checkedAt)
        }

        if let checkedAt = observation.lastCheckedAt {
            return .noData(checkedAt: checkedAt)
        }

        return .connect
    }

    /// HealthKit queries cannot be reliably cancelled once submitted. A newer
    /// generation always wins so a late result cannot replace fresher context.
    static func acceptsCompletion(
        generation: UInt,
        currentGeneration: UInt
    ) -> Bool {
        generation == currentGeneration
    }
}

enum ScreenTimeConnectionAuthorization: Equatable {
    case unavailable
    case notDetermined
    case approved
    case denied
}

enum ScreenTimeConnectionPresentation: Equatable {
    case unavailable
    case connect
    case needsAttention
    case chooseSelection
    case configured(selectionSummary: String)

    static func resolve(
        authorization: ScreenTimeConnectionAuthorization,
        selectionSummary: String?
    ) -> Self {
        switch authorization {
        case .unavailable:
            return .unavailable
        case .notDetermined:
            return .connect
        case .denied:
            return .needsAttention
        case .approved:
            guard let selectionSummary, !selectionSummary.isEmpty else {
                return .chooseSelection
            }
            return .configured(selectionSummary: selectionSummary)
        }
    }
}
