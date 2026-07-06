import SwiftUI

#if canImport(DeviceActivity)
import DeviceActivity

@main
struct PhoneInTheOtherRoomScreenTimeReport: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        PhoneOtherScreenTimeReportScene(
            context: .phoneOtherToday,
            title: "Today",
            emptyCaption: "No selected screen time yet"
        )
        PhoneOtherScreenTimeReportScene(
            context: .phoneOtherWeekly,
            title: "7-day trend",
            emptyCaption: "No selected screen time this week"
        )
        PhoneOtherScreenTimeReportScene(
            context: .phoneOtherLateNight,
            title: "Late screen time",
            emptyCaption: "No selected bedtime screen time"
        )
    }
}

struct PhoneOtherScreenTimeReportScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context
    let title: String
    let emptyCaption: String

    let content: (PhoneOtherScreenTimeConfiguration) -> PhoneOtherScreenTimeReportView

    init(context: DeviceActivityReport.Context, title: String, emptyCaption: String) {
        self.context = context
        self.title = title
        self.emptyCaption = emptyCaption
        self.content = { configuration in
            PhoneOtherScreenTimeReportView(configuration: configuration)
        }
    }

    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> PhoneOtherScreenTimeConfiguration {
        var totalDuration: TimeInterval = 0
        var segments: [PhoneOtherScreenTimeSegment] = []
        var pickupCount = 0

        for await deviceData in data {
            for await segment in deviceData.activitySegments {
                totalDuration += segment.totalActivityDuration
                pickupCount += segment.totalPickupsWithoutApplicationActivity
                segments.append(
                    PhoneOtherScreenTimeSegment(
                        startDate: segment.dateInterval.start,
                        duration: segment.totalActivityDuration
                    )
                )
            }
        }

        return PhoneOtherScreenTimeConfiguration(
            title: title,
            emptyCaption: emptyCaption,
            totalDuration: totalDuration,
            pickupCount: pickupCount,
            segments: segments
        )
    }
}

struct PhoneOtherScreenTimeConfiguration: Equatable {
    var title: String
    var emptyCaption: String
    var totalDuration: TimeInterval
    var pickupCount: Int
    var segments: [PhoneOtherScreenTimeSegment]
}

struct PhoneOtherScreenTimeSegment: Identifiable, Equatable {
    let id = UUID()
    var startDate: Date
    var duration: TimeInterval
}

struct PhoneOtherScreenTimeReportView: View {
    var configuration: PhoneOtherScreenTimeConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(formattedDuration(configuration.totalDuration))
                    .font(.system(.title3, design: .monospaced).weight(.black))
                    .foregroundStyle(.white)
                Spacer(minLength: 8)
                Text(configuration.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.62))
            }

            if configuration.totalDuration <= 0 {
                Text(configuration.emptyCaption)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.62))
            } else {
                HStack(alignment: .bottom, spacing: 5) {
                    ForEach(configuration.segments.suffix(7)) { segment in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color(red: 0.96, green: 0.72, blue: 0.18))
                            .frame(height: barHeight(for: segment.duration))
                    }
                }
                Text("\(configuration.pickupCount) pickups without app activity")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.56))
            }
        }
    }

    private func barHeight(for duration: TimeInterval) -> CGFloat {
        let maxDuration = max(configuration.segments.map(\.duration).max() ?? 1, 1)
        return max(8, min(42, CGFloat(duration / maxDuration) * 42))
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = max(0, Int(duration / 60))
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
        return "\(minutes)m"
    }
}
#endif

