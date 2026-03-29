import Foundation

/// Reports test results to the Qase TestOps API.
public actor TestOpsReporter: Reporter {
    private let client: QaseAPIClient
    private var runID: Int?

    public init(client: QaseAPIClient) {
        self.client = client
    }

    public func start(config: QaseConfig) async throws {
        if let existingRunID = config.runID {
            runID = existingRunID
        } else {
            runID = try await client.createRun(
                title: config.runTitle,
                description: config.runDescription,
                environment: config.environment
            )
        }
        QaseLogger.log("Qase run started: \(runID ?? -1)")
    }

    public func report(results: [TestResult], config: QaseConfig) async throws {
        guard let runID else { return }
        guard !results.isEmpty else { return }

        // Upload attachments first, then submit results
        var resultPayloads: [[String: Any]] = []

        for result in results {
            // One API result per case ID. If no case IDs, report as ad-hoc.
            let caseIDs = result.caseIDs.isEmpty ? [nil as Int?] : result.caseIDs.map(Optional.init)

            for caseID in caseIDs {
                var payload: [String: Any] = [
                    "status": result.status.rawValue,
                    "time_ms": result.timeMs,
                ]

                if let caseID {
                    payload["case_id"] = caseID
                }
                if let comment = result.comment {
                    payload["comment"] = comment
                }
                if !result.steps.isEmpty {
                    payload["steps"] = result.steps.map(\.apiPayload)
                }
                if !result.attachmentHashes.isEmpty {
                    payload["attachments"] = result.attachmentHashes
                }
                if !result.fields.isEmpty {
                    payload["custom_field"] = result.fields
                }

                resultPayloads.append(payload)
            }
        }

        // Batch upload respecting the 2000-result API limit
        let batchSize = min(config.batchSize, 2000)
        for batchStart in stride(from: 0, to: resultPayloads.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, resultPayloads.count)
            let batch = Array(resultPayloads[batchStart..<batchEnd])
            let jsonData: Data
            do {
                jsonData = try JSONSerialization.data(withJSONObject: ["results": batch])
            } catch {
                continue
            }
            try await client.uploadResults(jsonData: jsonData, runID: runID)
        }

        QaseLogger.log("Reported \(resultPayloads.count) result(s) to Qase run \(runID)")
    }

    public func finish(config: QaseConfig) async throws {
        guard let runID, config.autoComplete else { return }
        try await client.completeRun(runID: runID)
        QaseLogger.log("Qase run \(runID) completed")
    }
}

// MARK: - StepResult API Payload

extension StepResult {
    var apiPayload: [String: Any] {
        var dict: [String: Any] = [
            "position": position,
            "status": status.rawValue,
        ]
        if let comment { dict["comment"] = comment }
        if !attachments.isEmpty { dict["attachments"] = attachments }
        if !steps.isEmpty { dict["steps"] = steps.map(\.apiPayload) }
        return dict
    }
}
