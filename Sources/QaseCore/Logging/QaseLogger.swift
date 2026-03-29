import Foundation

/// Simple logger for Qase reporter diagnostics. Controlled by QASE_DEBUG env var.
public enum QaseLogger: Sendable {
    private static let isEnabled: Bool = {
        let value = ProcessInfo.processInfo.environment["QASE_DEBUG"] ?? ""
        return value.lowercased() == "true" || value == "1"
    }()

    public static func log(_ message: @autoclosure () -> String) {
        guard isEnabled else { return }
        print("[Qase] \(message())")
    }
}
