/// Operating mode for the Qase reporter.
public enum QaseMode: String, Sendable {
    /// Upload results to Qase TestOps in real time.
    case testops
    /// Write results to a local JSON file (no network).
    case report
    /// Disabled — no reporting.
    case off
}
