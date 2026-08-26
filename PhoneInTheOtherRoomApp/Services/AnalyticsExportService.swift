import Foundation

enum AnalyticsExportService {
    static func writeJSON(package: AnalyticsExportPackage) throws -> URL {
        let data = try FocusAnalyticsEngine.jsonData(for: package)
        let url = exportURL(filename: "counting-sheep-analytics.json")
        try data.write(to: url, options: .atomic)
        return url
    }

    static func writeCSV(records: [AnalyticsDayRecord], privacyMode: AnalyticsExportPrivacyMode) throws -> URL {
        let csv = FocusAnalyticsEngine.csvString(for: records, privacyMode: privacyMode)
        let url = exportURL(filename: "counting-sheep-analytics.csv")
        try csv.data(using: .utf8)?.write(to: url, options: .atomic)
        return url
    }

    private static func exportURL(filename: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    }
}
