import Foundation

/// Configuration for the Qase reporter, resolved from env vars, config file, and programmatic overrides.
public struct QaseConfig: Sendable {
    public var mode: QaseMode
    public var apiToken: String
    public var project: String
    public var host: String
    public var runID: Int?
    public var runTitle: String
    public var runDescription: String
    public var autoComplete: Bool
    public var batchSize: Int
    public var environment: String?

    public init(
        mode: QaseMode = .off,
        apiToken: String = "",
        project: String = "",
        host: String = "qase.io",
        runID: Int? = nil,
        runTitle: String = "Automated Test Run",
        runDescription: String = "",
        autoComplete: Bool = true,
        batchSize: Int = 200,
        environment: String? = nil
    ) {
        self.mode = mode
        self.apiToken = apiToken
        self.project = project
        self.host = host
        self.runID = runID
        self.runTitle = runTitle
        self.runDescription = runDescription
        self.autoComplete = autoComplete
        self.batchSize = batchSize
        self.environment = environment
    }
}
