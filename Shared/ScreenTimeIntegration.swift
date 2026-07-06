import Foundation

enum ScreenTimeSelectionScope: String, CaseIterable, Identifiable {
    case distracting
    case productive
    case bedtime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .distracting: return "Screen Time"
        case .productive: return "Productivity"
        case .bedtime: return "Late Screen Time"
        }
    }

    var pickerTitle: String {
        switch self {
        case .distracting: return "Choose distracting apps"
        case .productive: return "Choose productive apps"
        case .bedtime: return "Choose bedtime apps"
        }
    }

    var detail: String {
        switch self {
        case .distracting:
            return "Apps and categories to count as avoidable screen time."
        case .productive:
            return "Optional work or learning apps that should be separated from distractions."
        case .bedtime:
            return "Apps and sites to watch during the wind-down window."
        }
    }
}

#if SCREEN_TIME_REPORTS && canImport(DeviceActivity)
import DeviceActivity

extension DeviceActivityReport.Context {
    static let phoneOtherToday = Self("phone-other.today")
    static let phoneOtherWeekly = Self("phone-other.weekly")
    static let phoneOtherLateNight = Self("phone-other.late-night")
}
#endif
