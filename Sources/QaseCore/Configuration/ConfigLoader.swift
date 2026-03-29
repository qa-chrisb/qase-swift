import Foundation

/// Loads ``QaseConfig`` using a 3-tier priority: explicit overrides > environment variables > JSON config file > defaults.
public struct ConfigLoader: Sendable {

    public init() {}

    /// Resolves configuration by merging all sources.
    /// - Parameter overrides: Programmatic overrides (highest priority).
    /// - Returns: Fully resolved ``QaseConfig``.
    public func load(overrides: QaseConfig? = nil) -> QaseConfig {
        let fileConfig = loadFromFile()
        let envConfig = loadFromEnvironment()

        // Start with defaults, layer file, then env, then explicit overrides
        var config = QaseConfig()

        // File layer
        if let file = fileConfig {
            merge(into: &config, from: file)
        }

        // Env layer
        merge(into: &config, from: envConfig)

        // Explicit overrides
        if let overrides {
            merge(into: &config, from: overrides)
        }

        return config
    }

    // MARK: - Environment Variables

    private func loadFromEnvironment() -> QaseConfig {
        let env = ProcessInfo.processInfo.environment

        var config = QaseConfig()

        if let mode = env["QASE_MODE"].flatMap(QaseMode.init(rawValue:)) {
            config.mode = mode
        }
        if let token = env["QASE_TESTOPS_API_TOKEN"], !token.isEmpty {
            config.apiToken = token
        }
        if let project = env["QASE_TESTOPS_PROJECT"], !project.isEmpty {
            config.project = project
        }
        if let host = env["QASE_TESTOPS_API_HOST"], !host.isEmpty {
            config.host = host
        }
        if let runID = env["QASE_TESTOPS_RUN_ID"].flatMap(Int.init) {
            config.runID = runID
        }
        if let title = env["QASE_TESTOPS_RUN_TITLE"], !title.isEmpty {
            config.runTitle = title
        }
        if let complete = env["QASE_TESTOPS_RUN_COMPLETE"] {
            config.autoComplete = complete.lowercased() == "true" || complete == "1"
        }
        if let batch = env["QASE_TESTOPS_BATCH_SIZE"].flatMap(Int.init) {
            config.batchSize = batch
        }
        if let environment = env["QASE_TESTOPS_ENVIRONMENT"], !environment.isEmpty {
            config.environment = environment
        }

        return config
    }

    // MARK: - Config File

    private func loadFromFile() -> QaseConfig? {
        let fileManager = FileManager.default
        let configPath = fileManager.currentDirectoryPath + "/qase.config.json"

        guard let data = fileManager.contents(atPath: configPath) else { return nil }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let testops = json["testops"] as? [String: Any]
        else { return nil }

        var config = QaseConfig()

        if let mode = (testops["mode"] as? String).flatMap(QaseMode.init(rawValue:)) {
            config.mode = mode
        }
        if let api = testops["api"] as? [String: Any] {
            if let token = api["token"] as? String, !token.isEmpty {
                config.apiToken = token
            }
            if let host = api["host"] as? String, !host.isEmpty {
                config.host = host
            }
        }
        if let project = testops["project"] as? String, !project.isEmpty {
            config.project = project
        }
        if let run = testops["run"] as? [String: Any] {
            if let title = run["title"] as? String { config.runTitle = title }
            if let desc = run["description"] as? String { config.runDescription = desc }
            if let complete = run["complete"] as? Bool { config.autoComplete = complete }
        }
        if let batch = testops["batch_size"] as? Int {
            config.batchSize = batch
        }
        if let environment = testops["environment"] as? String {
            config.environment = environment
        }

        return config
    }

    // MARK: - Merge

    /// Merges non-default values from `source` into `target`.
    private func merge(into target: inout QaseConfig, from source: QaseConfig) {
        let defaults = QaseConfig()

        if source.mode != defaults.mode { target.mode = source.mode }
        if !source.apiToken.isEmpty { target.apiToken = source.apiToken }
        if !source.project.isEmpty { target.project = source.project }
        if source.host != defaults.host { target.host = source.host }
        if source.runID != nil { target.runID = source.runID }
        if source.runTitle != defaults.runTitle { target.runTitle = source.runTitle }
        if !source.runDescription.isEmpty { target.runDescription = source.runDescription }
        if source.autoComplete != defaults.autoComplete { target.autoComplete = source.autoComplete }
        if source.batchSize != defaults.batchSize { target.batchSize = source.batchSize }
        if source.environment != nil { target.environment = source.environment }
    }
}
