/// Protocol for reporting test results to a backend (Qase API or local file).
public protocol Reporter: Sendable {
    /// Called once before any results are reported. Creates a run if needed.
    func start(config: QaseConfig) async throws

    /// Reports a batch of test results.
    func report(results: [TestResult], config: QaseConfig) async throws

    /// Called after all results have been reported. Completes the run if configured.
    func finish(config: QaseConfig) async throws
}
