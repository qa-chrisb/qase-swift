import Foundation

/// Loads ``QaseConfig`` using a 3-tier priority: explicit overrides > environment variables > JSON config file > defaults.
public struct ConfigLoader: Sendable {

    public init() {}

    /// Resolves configuration by merging all sources.
    /// - Parameters:
    ///   - overrides: Programmatic overrides (highest priority).
    ///   - searchPaths: Additional directories to search for `.env` and `qase.config.json` files.
    /// - Returns: Fully resolved ``QaseConfig``.
    public func load(overrides: QaseConfig? = nil, searchPaths: [String] = []) -> QaseConfig {
        let fileConfig = loadFromFile(searchPaths: searchPaths)
        let dotenvConfig = loadFromDotEnv(searchPaths: searchPaths)
        let envConfig = loadFromEnvironment()

        // Priority: defaults < config file < .env file < env vars < explicit overrides
        var config = QaseConfig()

        if let file = fileConfig {
            merge(into: &config, from: file)
        }
        if let dotenv = dotenvConfig {
            merge(into: &config, from: dotenv)
        }
        merge(into: &config, from: envConfig)
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

    // MARK: - .env File

    private func loadFromDotEnv(searchPaths: [String]) -> QaseConfig? {
        let fileManager = FileManager.default
        let candidates = searchPaths + [fileManager.currentDirectoryPath]

        var dotenv: [String: String]?
        for dir in candidates {
            let path = (dir as NSString).appendingPathComponent(".env")
            if let contents = try? String(contentsOfFile: path, encoding: .utf8) {
                dotenv = parseDotEnv(contents)
                break
            }
        }

        guard let env = dotenv else { return nil }

        var config = QaseConfig()

        // Support both QASE_TESTOPS_* and shorthand QASE_API_TOKEN / QASE_PROJECT_CODE
        if let token = env["QASE_TESTOPS_API_TOKEN"] ?? env["QASE_API_TOKEN"], !token.isEmpty {
            config.apiToken = token
        }
        if let project = env["QASE_TESTOPS_PROJECT"] ?? env["QASE_PROJECT_CODE"], !project.isEmpty {
            config.project = project
        }
        if let mode = (env["QASE_MODE"]).flatMap(QaseMode.init(rawValue:)) {
            config.mode = mode
        }
        if let host = env["QASE_TESTOPS_API_HOST"], !host.isEmpty {
            config.host = host
        }
        if let title = env["QASE_TESTOPS_RUN_TITLE"], !title.isEmpty {
            config.runTitle = title
        }
        if let complete = env["QASE_TESTOPS_RUN_COMPLETE"] {
            config.autoComplete = complete.lowercased() == "true" || complete == "1"
        }
        if let debug = env["QASE_DEBUG"], debug.lowercased() == "true" || debug == "1" {
            // Debug flag is handled by QaseLogger, not config — but log that we found a .env
        }

        QaseLogger.log("Loaded Qase config from .env file")
        return config
    }

    private func parseDotEnv(_ contents: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
            var value = String(parts[1]).trimmingCharacters(in: .whitespaces)
            // Strip surrounding quotes
            if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
               (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }
            result[key] = value
        }
        return result
    }

    // MARK: - Config File

    private func loadFromFile(searchPaths: [String] = []) -> QaseConfig? {
        let fileManager = FileManager.default
        let candidates = searchPaths + [fileManager.currentDirectoryPath]

        var data: Data?
        for dir in candidates {
            let path = (dir as NSString).appendingPathComponent("qase.config.json")
            if let d = fileManager.contents(atPath: path) {
                data = d
                break
            }
        }

        guard let data else { return nil }

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
