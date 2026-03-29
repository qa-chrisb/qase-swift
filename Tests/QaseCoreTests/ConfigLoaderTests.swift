import Testing
@testable import QaseCore

@Suite("ConfigLoader")
struct ConfigLoaderTests {

    @Test("defaults when no env or file")
    func defaultConfig() {
        let config = QaseConfig()
        #expect(config.mode == .off)
        #expect(config.apiToken.isEmpty)
        #expect(config.project.isEmpty)
        #expect(config.host == "qase.io")
        #expect(config.runID == nil)
        #expect(config.runTitle == "Automated Test Run")
        #expect(config.autoComplete == true)
        #expect(config.batchSize == 200)
    }

    @Test("explicit overrides take priority")
    func overrides() {
        let overrides = QaseConfig(
            mode: .testops,
            apiToken: "tok_123",
            project: "PROJ",
            host: "custom.qase.io",
            batchSize: 50
        )
        let config = ConfigLoader().load(overrides: overrides)
        #expect(config.mode == .testops)
        #expect(config.apiToken == "tok_123")
        #expect(config.project == "PROJ")
        #expect(config.host == "custom.qase.io")
        #expect(config.batchSize == 50)
    }
}

@Suite("TestStatus")
struct TestStatusTests {
    @Test("raw values match Qase API")
    func rawValues() {
        #expect(TestStatus.passed.rawValue == "passed")
        #expect(TestStatus.failed.rawValue == "failed")
        #expect(TestStatus.skipped.rawValue == "skipped")
        #expect(TestStatus.blocked.rawValue == "blocked")
        #expect(TestStatus.invalid.rawValue == "invalid")
    }
}

@Suite("QaseMode")
struct QaseModeTests {
    @Test("init from raw value")
    func initFromRawValue() {
        #expect(QaseMode(rawValue: "testops") == .testops)
        #expect(QaseMode(rawValue: "report") == .report)
        #expect(QaseMode(rawValue: "off") == .off)
        #expect(QaseMode(rawValue: "invalid") == nil)
    }
}
