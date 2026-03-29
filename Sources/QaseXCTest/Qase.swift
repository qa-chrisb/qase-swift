import Foundation
import XCTest
import QaseCore

/// Main entry point for the Qase XCTest reporter.
///
/// Provides static methods for step tracking, attachments, and configuration.
/// Registration is done via ``QaseTestObserver/register()``.
@MainActor
public final class Qase: Sendable {
    /// Shared singleton used by annotations, steps, and attachments.
    nonisolated static let shared = Qase()

    nonisolated let store = MetadataStore()

    private nonisolated init() {}

    // MARK: - Configuration

    /// Configures the reporter programmatically. Call before tests start.
    nonisolated public static func configure(
        token: String? = nil,
        project: String? = nil,
        mode: QaseMode? = nil,
        runID: Int? = nil,
        host: String? = nil
    ) {
        var config = QaseConfig()
        if let token { config.apiToken = token }
        if let project { config.project = project }
        if let mode { config.mode = mode }
        if let runID { config.runID = runID }
        if let host { config.host = host }
        QaseTestObserver.configOverride = config
    }

    // MARK: - Steps

    /// Executes a named test step, tracking it for Qase reporting.
    ///
    /// Wraps `XCTContext.runActivity(named:)` so steps appear in both Xcode results and Qase.
    /// Supports nesting naturally.
    ///
    /// ```swift
    /// Qase.step("Login") {
    ///     Qase.step("Enter email") { ... }
    ///     Qase.step("Tap submit") { ... }
    /// }
    /// ```
    @discardableResult
    public static func step<T>(
        _ name: String,
        expected: String? = nil,
        body: () throws -> T
    ) rethrows -> T {
        let testID = currentTestID()

        // Track step entry
        let position: Int
        if let testID {
            position = shared.store.read(for: testID).map { metadata in
                let depth = metadata.stepStack.count
                return depth < metadata.stepPositionCounters.count
                    ? metadata.stepPositionCounters[depth] + 1
                    : 1
            } ?? 1

            shared.store.update(for: testID) { metadata in
                let depth = metadata.stepStack.count
                if depth < metadata.stepPositionCounters.count {
                    metadata.stepPositionCounters[depth] = position
                } else {
                    metadata.stepPositionCounters.append(position)
                }
                metadata.stepStack.append(position)
            }
        } else {
            position = 1
        }

        var stepStatus: TestStatus = .passed
        var stepComment: String?

        let result: T
        do {
            result = try XCTContext.runActivity(named: name) { _ in
                try body()
            }
        } catch {
            stepStatus = .failed
            stepComment = error.localizedDescription
            if let testID {
                recordStep(testID: testID, position: position, name: name, expected: expected, status: stepStatus, comment: stepComment)
            }
            throw error
        }

        if let testID {
            recordStep(testID: testID, position: position, name: name, expected: expected, status: stepStatus, comment: stepComment)
        }

        return result
    }

    private static func recordStep(
        testID: ObjectIdentifier,
        position: Int,
        name: String,
        expected: String?,
        status: TestStatus,
        comment: String?
    ) {
        shared.store.update(for: testID) { metadata in
            _ = metadata.stepStack.popLast()

            let step = StepResult(
                position: position,
                status: status,
                comment: [name, expected, comment].compactMap { $0 }.joined(separator: " — ")
            )

            if metadata.stepStack.isEmpty {
                metadata.steps.append(step)
            } else {
                Qase.appendNestedStep(step, to: &metadata.steps, at: metadata.stepStack)
            }
        }
    }

    /// Recursively appends a step to the correct parent in the step hierarchy.
    nonisolated private static func appendNestedStep(
        _ step: StepResult,
        to steps: inout [StepResult],
        at path: [Int]
    ) {
        guard !steps.isEmpty else {
            steps.append(step)
            return
        }
        let lastIndex = steps.count - 1
        if path.count <= 1 {
            steps[lastIndex].steps.append(step)
        } else {
            let remaining = Array(path.dropFirst())
            appendNestedStep(step, to: &steps[lastIndex].steps, at: remaining)
        }
    }

    // MARK: - Attachments

    /// Attaches raw data to the current test's Qase result.
    nonisolated public static func attach(data: Data, named name: String, mimeType: String) {
        guard let testID = currentTestID() else { return }
        let info = AttachmentInfo(data: data, name: name, mimeType: mimeType)
        shared.store.update(for: testID) { metadata in
            metadata.attachments.append(info)
        }
    }

    /// Attaches a screenshot to the current test's Qase result.
    public static func attach(screenshot: XCUIScreenshot, named name: String = "screenshot") {
        attach(data: screenshot.pngRepresentation, named: "\(name).png", mimeType: "image/png")
    }

    /// Attaches a file at the given URL to the current test's Qase result.
    nonisolated public static func attach(file url: URL) {
        guard let data = try? Data(contentsOf: url) else { return }
        let mimeType = url.pathExtension == "json" ? "application/json"
            : url.pathExtension == "png" ? "image/png"
            : url.pathExtension == "txt" ? "text/plain"
            : "application/octet-stream"
        attach(data: data, named: url.lastPathComponent, mimeType: mimeType)
    }

    // MARK: - Helpers

    nonisolated private static func currentTestID() -> ObjectIdentifier? {
        Thread.current.threadDictionary["__qase_test_id__"] as? ObjectIdentifier
    }
}
