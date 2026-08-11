#if DEBUG
import Foundation

struct ScreenbookLaunchRequest {
    static let scenarioArgument = "-screenbook-scenario"
    static let runIDArgument = "-screenbook-run-id"
    static let manifestArgument = "-screenbook-export-manifest"

    let scenarioID: String?
    let runID: String
    let exportsManifest: Bool

    var kind: ScreenbookScenarioKind? {
        scenarioID.flatMap(ScreenbookScenarioKind.init(rawValue:))
    }

    static var current: ScreenbookLaunchRequest? {
        let arguments = ProcessInfo.processInfo.arguments
        let scenarioID = value(after: scenarioArgument, in: arguments)
        let exportsManifest = value(after: manifestArgument, in: arguments) == "YES"
        guard scenarioID != nil || exportsManifest else { return nil }
        return ScreenbookLaunchRequest(
            scenarioID: scenarioID,
            runID: value(after: runIDArgument, in: arguments) ?? "missing-run-id",
            exportsManifest: exportsManifest
        )
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }
}

enum ScreenbookCaptureReadiness {
    private struct Signal: Codable {
        let schemaVersion: Int
        let runID: String
        let scenarioID: String
        let status: String
        let message: String?
    }

    static func reportReady(_ request: ScreenbookLaunchRequest) throws {
        try writeRegistry()
        try writeSignal(Signal(
            schemaVersion: 1,
            runID: request.runID,
            scenarioID: request.scenarioID ?? "registry-export",
            status: "ready",
            message: nil
        ))
    }

    static func reportFailure(_ request: ScreenbookLaunchRequest, message: String) throws {
        try writeRegistry()
        try writeSignal(Signal(
            schemaVersion: 1,
            runID: request.runID,
            scenarioID: request.scenarioID ?? "missing-scenario",
            status: "failed",
            message: message
        ))
    }

    private static func writeRegistry() throws {
        try ScreenbookScenarioRegistry.encodedManifest().write(
            to: try directory().appendingPathComponent("registry.json"),
            options: .atomic
        )
    }

    private static func writeSignal(_ signal: Signal) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(signal).write(
            to: try directory().appendingPathComponent("readiness.json"),
            options: .atomic
        )
    }

    private static func directory() throws -> URL {
        let base = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("screenbook", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
#endif
