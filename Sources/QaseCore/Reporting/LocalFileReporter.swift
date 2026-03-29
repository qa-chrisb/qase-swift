import Foundation

/// Writes test results to a local JSON file instead of uploading to Qase.
public actor LocalFileReporter: Reporter {
    private var allResults: [TestResult] = []
    private let outputPath: String

    public init(outputPath: String = "qase-results.json") {
        self.outputPath = outputPath
    }

    public func start(config: QaseConfig) async throws {
        allResults = []
        QaseLogger.log("Qase local reporter started (output: \(outputPath))")
    }

    public func report(results: [TestResult], config: QaseConfig) async throws {
        allResults.append(contentsOf: results)
    }

    public func finish(config: QaseConfig) async throws {
        let payload = allResults.map { result -> [String: Any] in
            var dict: [String: Any] = [
                "test_name": result.testName,
                "case_ids": result.caseIDs,
                "status": result.status.rawValue,
                "time_ms": result.timeMs,
            ]
            if let comment = result.comment { dict["comment"] = comment }
            if let title = result.title { dict["title"] = title }
            if let suite = result.suite { dict["suite"] = suite }
            if !result.steps.isEmpty {
                dict["steps"] = result.steps.map(\.apiPayload)
            }
            if !result.fields.isEmpty {
                dict["fields"] = result.fields
            }
            return dict
        }

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted) else {
            return
        }

        let url = URL(fileURLWithPath: outputPath)
        try? data.write(to: url)
        QaseLogger.log("Wrote \(allResults.count) result(s) to \(outputPath)")
    }
}
