import Testing
@testable import QaseCore

/// A mock reporter that records calls for verification.
actor MockReporter: Reporter {
    var startCalled = false
    var reportedBatches: [[TestResult]] = []
    var finishCalled = false

    func start(config: QaseConfig) async throws {
        startCalled = true
    }

    func report(results: [TestResult], config: QaseConfig) async throws {
        reportedBatches.append(results)
    }

    func finish(config: QaseConfig) async throws {
        finishCalled = true
    }
}

@Suite("ResultBatcher")
struct ResultBatcherTests {

    @Test("flushes when batch size reached")
    func autoFlush() async throws {
        let mock = MockReporter()
        let config = QaseConfig(batchSize: 2)
        let batcher = ResultBatcher(reporter: mock, config: config)

        let r1 = TestResult(status: .passed, testName: "test1")
        let r2 = TestResult(status: .failed, testName: "test2")

        try await batcher.add(r1)
        #expect(await mock.reportedBatches.isEmpty)

        try await batcher.add(r2)
        #expect(await mock.reportedBatches.count == 1)
        #expect(await mock.reportedBatches.first?.count == 2)
    }

    @Test("flush sends remaining results")
    func manualFlush() async throws {
        let mock = MockReporter()
        let config = QaseConfig(batchSize: 100)
        let batcher = ResultBatcher(reporter: mock, config: config)

        try await batcher.add(TestResult(status: .passed, testName: "test1"))
        #expect(await batcher.pendingCount == 1)

        try await batcher.flush()
        #expect(await batcher.pendingCount == 0)
        #expect(await mock.reportedBatches.count == 1)
    }

    @Test("flush with no pending results is a no-op")
    func emptyFlush() async throws {
        let mock = MockReporter()
        let config = QaseConfig()
        let batcher = ResultBatcher(reporter: mock, config: config)

        try await batcher.flush()
        #expect(await mock.reportedBatches.isEmpty)
    }
}
