/// Result of a single test step, reported within a test result.
public struct StepResult: Sendable, Codable {
    /// 1-based position matching the step definition in Qase.
    public var position: Int
    public var status: TestStatus
    public var comment: String?
    public var attachments: [String]

    /// Child steps for nested step hierarchies.
    public var steps: [StepResult]

    public init(
        position: Int,
        status: TestStatus,
        comment: String? = nil,
        attachments: [String] = [],
        steps: [StepResult] = []
    ) {
        self.position = position
        self.status = status
        self.comment = comment
        self.attachments = attachments
        self.steps = steps
    }
}
