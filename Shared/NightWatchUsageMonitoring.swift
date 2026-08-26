import Foundation

enum NightWatchUsageActivity: String, CaseIterable {
    case windDown
    case overnight
    case morningQuiet

    var phase: NightWatchPhase {
        switch self {
        case .windDown: return .windDown
        case .overnight: return .overnight
        case .morningQuiet: return .morningQuiet
        }
    }

    var activityRawValue: String { "ollie.usage.\(rawValue)" }
    var eventRawValue: String { "ollie.usage.threshold.\(rawValue)" }

    init?(activityRawValue: String) {
        self.init(rawValue: activityRawValue.replacingOccurrences(of: "ollie.usage.", with: ""))
    }
}

#if os(iOS) && canImport(DeviceActivity)
import DeviceActivity

extension NightWatchUsageActivity {
    var activityName: DeviceActivityName { DeviceActivityName(activityRawValue) }
    var eventName: DeviceActivityEvent.Name { DeviceActivityEvent.Name(eventRawValue) }

    init?(activityName: DeviceActivityName) {
        self.init(activityRawValue: activityName.rawValue)
    }
}
#endif
