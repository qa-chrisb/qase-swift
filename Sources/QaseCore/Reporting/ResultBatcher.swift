import Foundation

/// Collects test results and flushes them in batches to a ``Reporter``.
public actor ResultBatcher {
    private var pending: [TestResult] = []
    private let reporter: any Reporter
    private let config: QaseConfig

    public init(reporter: any Reporter, config: QaseConfig) {
        self.reporter = reporter
        self.config = config
    }

    /// Adds a result to the batch. Flushes automatically when batch size is reached.
    public func add(_ result: TestResult) async throws {
        pending.append(result)

        if pending.count >= config.batchSize {
            try await flush()
        }
    }

    /// Flushes all pending results to the reporter.
    public func flush() async throws {
        guard !pending.isEmpty else { return }
        let batch = pending
        pending = []
        try await reporter.report(results: batch, config: config)
    }

    /// Returns the number of pending results.
    public var pendingCount: Int { pending.count }
}
