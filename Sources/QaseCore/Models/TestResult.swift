import Foundation

/// A completed test result ready for submission to Qase.
public struct TestResult: Sendable {
    public var caseIDs: [Int]
    public var status: TestStatus
    public var timeMs: Int
    public var comment: String?
    public var steps: [StepResult]
    public var attachmentHashes: [String]
    public var fields: [String: String]

    /// Original test name from the framework (e.g. "-[AuthFlowUITests testLogin]").
    public var testName: String

    /// Suite path override (e.g. "Auth/Login").
    public var suite: String?

    /// Title override for Qase.
    public var title: String?

    public init(
        caseIDs: [Int] = [],
        status: TestStatus,
        timeMs: Int = 0,
        comment: String? = nil,
        steps: [StepResult] = [],
        attachmentHashes: [String] = [],
        fields: [String: String] = [:],
        testName: String = "",
        suite: String? = nil,
        title: String? = nil
    ) {
        self.caseIDs = caseIDs
        self.status = status
        self.timeMs = timeMs
        self.comment = comment
        self.steps = steps
        self.attachmentHashes = attachmentHashes
        self.fields = fields
        self.testName = testName
        self.suite = suite
        self.title = title
    }
}
