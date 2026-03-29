import Foundation
import os
import QaseCore

/// Per-test metadata collected via annotation methods during test execution.
struct TestMetadata: Sendable {
    var caseIDs: [Int] = []
    var title: String?
    var suite: String?
    var fields: [String: String] = [:]
    var ignore: Bool = false
    var steps: [StepResult] = []
    var attachments: [AttachmentInfo] = []
    var issues: [IssueInfo] = []
    var startTime: CFAbsoluteTime = 0

    /// Tracks the current step nesting for `Qase.step()`.
    var stepStack: [Int] = []
    /// Next position counter per nesting depth.
    var stepPositionCounters: [Int] = []
}

/// Captured XCTIssue information (avoids storing XCTest types in QaseCore).
struct IssueInfo: Sendable {
    enum IssueType: Sendable {
        case assertionFailure
        case thrownError
        case uncaughtException
        case other
    }

    var type: IssueType
    var description: String
    var detailedDescription: String?
    var sourceFile: String?
    var sourceLine: Int?
}

/// Thread-safe storage for per-test metadata, keyed by test ObjectIdentifier.
///
/// Annotation methods (`qase(id:)`, `Qase.step()`, etc.) are synchronous and called from
/// XCTest's thread. The observer reads metadata in `testCaseDidFinish`. This store bridges
/// the two using an unfair lock for minimal overhead.
final class MetadataStore: Sendable {
    private let storage = OSAllocatedUnfairLock(initialState: [ObjectIdentifier: TestMetadata]())

    func initialize(for testCase: ObjectIdentifier) {
        storage.withLock { store in
            store[testCase] = TestMetadata(startTime: CFAbsoluteTimeGetCurrent())
        }
    }

    func update(for testCase: ObjectIdentifier, _ mutation: @Sendable (inout TestMetadata) -> Void) {
        storage.withLock { store in
            guard store[testCase] != nil else { return }
            mutation(&store[testCase]!)
        }
    }

    func consume(for testCase: ObjectIdentifier) -> TestMetadata? {
        storage.withLock { store in
            store.removeValue(forKey: testCase)
        }
    }

    func read(for testCase: ObjectIdentifier) -> TestMetadata? {
        storage.withLock { store in
            store[testCase]
        }
    }
}
