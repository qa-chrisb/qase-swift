/// Test result status matching Qase API values.
public enum TestStatus: String, Sendable, Codable {
    case passed
    case failed
    case skipped
    case blocked
    case invalid
}
