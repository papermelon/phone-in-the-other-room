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
            title: "Late evening",
            emptyCaption: "No selected app use in this evening window"
        )
        PhoneOtherScreenTimeReportScene(
            context: .phoneOtherWindDown,
            title: "Wind Down before bed",
            emptyCaption: "No selected app use during Wind Down"
        )
        PhoneOtherScreenTimeReportScene(
            context: .phoneOtherMorningQuiet,
            title: "After waking",
            emptyCaption: "No selected app use after waking"
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
        var samples: [ScreenTimeActivityBucket] = []
        var firstPickup: Date?
        var reportInterval: DateInterval?

        for await deviceData in data {
            if case .hourly(let interval) = deviceData.segmentInterval {
                reportInterval = interval
            }
            for await segment in deviceData.activitySegments {
                if let pickup = segment.firstPickup {
                    firstPickup = firstPickup.map { min($0, pickup) } ?? pickup
                }
                samples.append(
                    ScreenTimeActivityBucket(
                        startDate: segment.dateInterval.start,
                        endDate: segment.dateInterval.end,
                        selectedAppDuration: segment.totalActivityDuration
                    )
                )
            }
        }

        let buckets = reportInterval.map {
            ScreenTimeReportMath.hourlyBuckets(in: $0, from: samples)
        } ?? ScreenTimeReportMath.aggregate(samples)
        return PhoneOtherScreenTimeConfiguration(
            title: title,
            emptyCaption: emptyCaption,
            totalDuration: buckets.reduce(0) { $0 + $1.selectedAppDuration },
            windowDuration: reportInterval?.duration
                ?? buckets.reduce(0) { $0 + $1.intervalDuration },
            firstPickup: firstPickup,
            buckets: buckets
        )
    }
}

struct PhoneOtherScreenTimeConfiguration: Equatable {
    var title: String
    var emptyCaption: String
    var totalDuration: TimeInterval
    var windowDuration: TimeInterval
    var firstPickup: Date?
    var buckets: [ScreenTimeActivityBucket]
}

struct PhoneOtherScreenTimeReportView: View {
    var configuration: PhoneOtherScreenTimeConfiguration
    @State private var selectedBucketID: String?

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
                Text(windowShareLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))

                ScrollView(.horizontal) {
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(configuration.buckets) { bucket in
                            bucketButton(bucket)
                        }
                    }
                }
                .scrollIndicators(.hidden)

                if let selectedBucket {
                    Text(
                        "\(timeRange(selectedBucket)): \(formattedDuration(selectedBucket.selectedAppDuration)) in selected apps"
                    )
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                }

                activityTiming

                Text("Bars show selected-app time within each hour. Tap an hour for its exact time.")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.56))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }

    private func bucketButton(_ bucket: ScreenTimeActivityBucket) -> some View {
        let isSelected = selectedBucket?.id == bucket.id
        return Button {
            selectedBucketID = bucket.id
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(.white.opacity(0.08))
                        .frame(width: 34, height: 54)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color(red: 0.96, green: 0.72, blue: 0.18))
                        .frame(
                            width: 34,
                            height: max(3, CGFloat(bucket.fillFraction) * 54)
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(.white.opacity(isSelected ? 0.9 : 0), lineWidth: 2)
                }
                Text(bucket.startDate.formatted(.dateTime.hour()))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.68))
            }
        }
        .frame(minWidth: 44, minHeight: 72)
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(timeRange(bucket)), \(formattedDuration(bucket.selectedAppDuration)) in selected apps"
        )
    }

    private var activityTiming: some View {
        return VStack(alignment: .leading, spacing: 2) {
            if let firstPickup = configuration.firstPickup {
                Text("First iPhone pickup in this window: \(firstPickup.formatted(date: .omitted, time: .shortened))")
            }
            if let peak = ScreenTimeReportMath.peakBucket(in: configuration.buckets) {
                Text("Busiest selected-app hour: \(timeRange(peak))")
            }
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.white.opacity(0.68))
    }

    private var selectedBucket: ScreenTimeActivityBucket? {
        if let selectedBucketID,
           let selected = configuration.buckets.first(where: { $0.id == selectedBucketID }) {
            return selected
        }
        return ScreenTimeReportMath.peakBucket(in: configuration.buckets)
    }

    private var windowShareLabel: String {
        let percentage = ScreenTimeReportMath.selectedAppPercentage(
            selectedDuration: configuration.totalDuration,
            windowDuration: configuration.windowDuration
        )
        return "\(percentage)% of this report window was spent in the apps and categories you selected."
    }

    private func timeRange(_ bucket: ScreenTimeActivityBucket) -> String {
        let start = bucket.startDate.formatted(date: .omitted, time: .shortened)
        let end = bucket.endDate.formatted(date: .omitted, time: .shortened)
        return "\(start)–\(end)"
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
