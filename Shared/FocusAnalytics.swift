import Foundation

enum AnalyticsMetricSource: String, Codable {
    case focusRun
    case manual
    case screenTimePlaceholder
    case screenTimeReport
    case healthPlaceholder
    case healthKit
}

enum AnalyticsExportPrivacyMode: String, Codable, CaseIterable, Identifiable {
    case exactDates
    case relativeDays

    var id: String { rawValue }
}

struct ManualAnalyticsEntry: Codable, Identifiable, Equatable {
    var day: Date
    var screenTimeMinutes: Int?
    var socialScreenTimeMinutes: Int?
    var bedtimeScreenTimeMinutes: Int?
    var sleepMinutes: Int?
    var updatedAt: Date

    var id: Date { day }

    init(
        day: Date,
        screenTimeMinutes: Int? = nil,
        socialScreenTimeMinutes: Int? = nil,
        bedtimeScreenTimeMinutes: Int? = nil,
        sleepMinutes: Int? = nil,
        updatedAt: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.day = calendar.startOfDay(for: day)
        self.screenTimeMinutes = screenTimeMinutes
        self.socialScreenTimeMinutes = socialScreenTimeMinutes
        self.bedtimeScreenTimeMinutes = bedtimeScreenTimeMinutes
        self.sleepMinutes = sleepMinutes
        self.updatedAt = updatedAt
    }
}

struct AnalyticsDayRecord: Codable, Identifiable, Equatable {
    var day: Date
    var focusMinutes: Int
    var successfulRuns: Int
    var warnings: Int
    var rewardsEarned: Int
    var screenTimeMinutes: Int?
    var socialScreenTimeMinutes: Int?
    var bedtimeScreenTimeMinutes: Int?
    var sleepMinutes: Int?
    var screenTimeSource: AnalyticsMetricSource?
    var socialScreenTimeSource: AnalyticsMetricSource?
    var bedtimeScreenTimeSource: AnalyticsMetricSource?
    var sleepSource: AnalyticsMetricSource?

    var id: Date { day }

    init(
        day: Date,
        focusMinutes: Int = 0,
        successfulRuns: Int = 0,
        warnings: Int = 0,
        rewardsEarned: Int = 0,
        screenTimeMinutes: Int? = nil,
        socialScreenTimeMinutes: Int? = nil,
        bedtimeScreenTimeMinutes: Int? = nil,
        sleepMinutes: Int? = nil,
        screenTimeSource: AnalyticsMetricSource? = nil,
        socialScreenTimeSource: AnalyticsMetricSource? = nil,
        bedtimeScreenTimeSource: AnalyticsMetricSource? = nil,
        sleepSource: AnalyticsMetricSource? = nil,
        calendar: Calendar = .current
    ) {
        self.day = calendar.startOfDay(for: day)
        self.focusMinutes = focusMinutes
        self.successfulRuns = successfulRuns
        self.warnings = warnings
        self.rewardsEarned = rewardsEarned
        self.screenTimeMinutes = screenTimeMinutes
        self.socialScreenTimeMinutes = socialScreenTimeMinutes
        self.bedtimeScreenTimeMinutes = bedtimeScreenTimeMinutes
        self.sleepMinutes = sleepMinutes
        self.screenTimeSource = screenTimeSource
        self.socialScreenTimeSource = socialScreenTimeSource
        self.bedtimeScreenTimeSource = bedtimeScreenTimeSource
        self.sleepSource = sleepSource
    }
}

struct AnalyticsCorrelation: Codable, Equatable {
    var title: String
    var xLabel: String
    var yLabel: String
    var coefficient: Double?
    var sampleSize: Int
    var placeholderSampleCount: Int = 0

    var strengthLabel: String {
        guard let coefficient else { return "Needs data" }
        let magnitude = abs(coefficient)
        if magnitude >= 0.7 { return "Strong" }
        if magnitude >= 0.4 { return "Moderate" }
        if magnitude >= 0.2 { return "Weak" }
        return "Very weak"
    }

    var directionLabel: String {
        guard let coefficient else { return "Not enough paired days" }
        if coefficient > 0.05 { return "Positive relationship" }
        if coefficient < -0.05 { return "Negative relationship" }
        return "No clear direction"
    }

    var coefficientLabel: String {
        guard let coefficient else { return "n/a" }
        return String(format: "%.2f", coefficient)
    }

    var provenanceLabel: String {
        placeholderSampleCount > 0 ? "\(placeholderSampleCount) placeholder days" : "No placeholder days"
    }
}

struct AnalyticsExportPackage: Codable, Equatable {
    var generatedAt: Date
    var appSchemaVersion: Int
    var privacyMode: AnalyticsExportPrivacyMode
    var days: [AnalyticsDayRecord]
    var correlations: [AnalyticsCorrelation]
}

enum FocusAnalyticsEngine {
    static let exportSchemaVersion = 2

    static func dayRecords(
        progress: UserProgress,
        days: Int = 30,
        endingAt date: Date = Date(),
        manualEntries: [ManualAnalyticsEntry] = [],
        screenTimePlaceholders: [Date: Int] = [:],
        sleepPlaceholders: [Date: Int] = [:],
        calendar: Calendar = .current
    ) -> [AnalyticsDayRecord] {
        let end = calendar.startOfDay(for: date)
        return (0..<max(1, days)).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: end) else { return nil }
            let focus = progress.record(for: day, calendar: calendar)
            let manual = manualEntry(for: day, in: manualEntries, calendar: calendar)
            let screenTime = placeholderValue(for: day, in: screenTimePlaceholders, calendar: calendar)
            let sleep = placeholderValue(for: day, in: sleepPlaceholders, calendar: calendar)
            return AnalyticsDayRecord(
                day: day,
                focusMinutes: focus?.completedFocusMinutes ?? 0,
                successfulRuns: focus?.successfulRuns ?? 0,
                warnings: focus?.warnings ?? 0,
                rewardsEarned: focus?.rewardsEarned ?? 0,
                screenTimeMinutes: manual?.screenTimeMinutes ?? screenTime,
                socialScreenTimeMinutes: manual?.socialScreenTimeMinutes,
                bedtimeScreenTimeMinutes: manual?.bedtimeScreenTimeMinutes,
                sleepMinutes: manual?.sleepMinutes ?? sleep,
                screenTimeSource: source(manualValue: manual?.screenTimeMinutes, placeholderValue: screenTime, placeholderSource: .screenTimePlaceholder),
                socialScreenTimeSource: manual?.socialScreenTimeMinutes == nil ? nil : .manual,
                bedtimeScreenTimeSource: manual?.bedtimeScreenTimeMinutes == nil ? nil : .manual,
                sleepSource: source(manualValue: manual?.sleepMinutes, placeholderValue: sleep, placeholderSource: .healthPlaceholder),
                calendar: calendar
            )
        }
    }

    static func correlations(for records: [AnalyticsDayRecord]) -> [AnalyticsCorrelation] {
        [
            AnalyticsCorrelation(
                title: "Quiet time vs Screen Time",
                xLabel: "Phone-free minutes around sleep",
                yLabel: "Screen time minutes",
                coefficient: pearson(records.compactMap { pair($0.focusMinutes, $0.screenTimeMinutes) }),
                sampleSize: records.filter { $0.screenTimeMinutes != nil }.count,
                placeholderSampleCount: records.filter { $0.screenTimeSource == .screenTimePlaceholder }.count
            ),
            AnalyticsCorrelation(
                title: "Quiet time vs Sleep",
                xLabel: "Phone-free minutes around sleep",
                yLabel: "Sleep minutes",
                coefficient: pearson(records.compactMap { pair($0.focusMinutes, $0.sleepMinutes) }),
                sampleSize: records.filter { $0.sleepMinutes != nil }.count,
                placeholderSampleCount: records.filter { $0.sleepSource == .healthPlaceholder }.count
            ),
            AnalyticsCorrelation(
                title: "Total Screen Time vs Sleep",
                xLabel: "Screen time minutes",
                yLabel: "Sleep minutes",
                coefficient: pearson(records.compactMap { record in
                    guard let screen = record.screenTimeMinutes else { return nil }
                    return pair(screen, record.sleepMinutes)
                }),
                sampleSize: records.filter { $0.screenTimeMinutes != nil && $0.sleepMinutes != nil }.count,
                placeholderSampleCount: records.filter { record in
                    record.screenTimeMinutes != nil &&
                    record.sleepMinutes != nil &&
                    (record.screenTimeSource == .screenTimePlaceholder || record.sleepSource == .healthPlaceholder)
                }.count
            ),
            AnalyticsCorrelation(
                title: "Bedtime Screen Time vs Sleep",
                xLabel: "Bedtime screen minutes",
                yLabel: "Sleep minutes",
                coefficient: pearson(records.compactMap { record in
                    guard let bedtimeScreen = record.bedtimeScreenTimeMinutes else { return nil }
                    return pair(bedtimeScreen, record.sleepMinutes)
                }),
                sampleSize: records.filter { $0.bedtimeScreenTimeMinutes != nil && $0.sleepMinutes != nil }.count,
                placeholderSampleCount: 0
            ),
            AnalyticsCorrelation(
                title: "Social Scrolling vs Sleep",
                xLabel: "Social screen minutes",
                yLabel: "Sleep minutes",
                coefficient: pearson(records.compactMap { record in
                    guard let socialScreen = record.socialScreenTimeMinutes else { return nil }
                    return pair(socialScreen, record.sleepMinutes)
                }),
                sampleSize: records.filter { $0.socialScreenTimeMinutes != nil && $0.sleepMinutes != nil }.count,
                placeholderSampleCount: 0
            )
        ]
    }

    static func exportPackage(records: [AnalyticsDayRecord], privacyMode: AnalyticsExportPrivacyMode = .exactDates, generatedAt: Date = Date()) -> AnalyticsExportPackage {
        AnalyticsExportPackage(
            generatedAt: generatedAt,
            appSchemaVersion: exportSchemaVersion,
            privacyMode: privacyMode,
            days: records,
            correlations: correlations(for: records)
        )
    }

    static func jsonData(for package: AnalyticsExportPackage) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(package)
    }

    static func csvString(for records: [AnalyticsDayRecord], privacyMode: AnalyticsExportPrivacyMode = .exactDates, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        var lines = ["day,focus_minutes,successful_runs,warnings,rewards_earned,screen_time_minutes,screen_time_source,social_screen_time_minutes,social_screen_time_source,bedtime_screen_time_minutes,bedtime_screen_time_source,sleep_minutes,sleep_source"]
        lines += records.enumerated().map { index, record in
            let fields: [String] = [
                dayLabel(for: record, index: index, total: records.count, privacyMode: privacyMode, formatter: formatter),
                "\(record.focusMinutes)",
                "\(record.successfulRuns)",
                "\(record.warnings)",
                "\(record.rewardsEarned)",
                record.screenTimeMinutes.map(String.init) ?? "",
                record.screenTimeSource?.rawValue ?? "",
                record.socialScreenTimeMinutes.map(String.init) ?? "",
                record.socialScreenTimeSource?.rawValue ?? "",
                record.bedtimeScreenTimeMinutes.map(String.init) ?? "",
                record.bedtimeScreenTimeSource?.rawValue ?? "",
                record.sleepMinutes.map(String.init) ?? "",
                record.sleepSource?.rawValue ?? ""
            ]
            return fields.joined(separator: ",")
        }
        return lines.joined(separator: "\n")
    }

    private static func pair(_ x: Int, _ y: Int?) -> (Double, Double)? {
        guard let y else { return nil }
        return (Double(x), Double(y))
    }

    private static func pearson(_ pairs: [(Double, Double)]) -> Double? {
        guard pairs.count >= 3 else { return nil }
        let xMean = pairs.reduce(0) { $0 + $1.0 } / Double(pairs.count)
        let yMean = pairs.reduce(0) { $0 + $1.1 } / Double(pairs.count)
        var numerator = 0.0
        var xDenominator = 0.0
        var yDenominator = 0.0

        for pair in pairs {
            let xDelta = pair.0 - xMean
            let yDelta = pair.1 - yMean
            numerator += xDelta * yDelta
            xDenominator += xDelta * xDelta
            yDenominator += yDelta * yDelta
        }

        let denominator = sqrt(xDenominator * yDenominator)
        guard denominator > 0 else { return nil }
        return numerator / denominator
    }

    private static func placeholderValue(for day: Date, in values: [Date: Int], calendar: Calendar) -> Int? {
        let normalizedDay = calendar.startOfDay(for: day)
        if let exact = values[normalizedDay] { return exact }
        return values.first { calendar.isDate($0.key, inSameDayAs: normalizedDay) }?.value
    }

    private static func manualEntry(for day: Date, in entries: [ManualAnalyticsEntry], calendar: Calendar) -> ManualAnalyticsEntry? {
        let normalizedDay = calendar.startOfDay(for: day)
        if let exact = entries.first(where: { $0.day == normalizedDay }) { return exact }
        return entries.first { calendar.isDate($0.day, inSameDayAs: normalizedDay) }
    }

    private static func source(manualValue: Int?, placeholderValue: Int?, placeholderSource: AnalyticsMetricSource) -> AnalyticsMetricSource? {
        if manualValue != nil { return .manual }
        if placeholderValue != nil { return placeholderSource }
        return nil
    }

    private static func dayLabel(for record: AnalyticsDayRecord, index: Int, total: Int, privacyMode: AnalyticsExportPrivacyMode, formatter: DateFormatter) -> String {
        switch privacyMode {
        case .exactDates:
            return formatter.string(from: record.day)
        case .relativeDays:
            return "day_\(index - max(0, total - 1))"
        }
    }
}
