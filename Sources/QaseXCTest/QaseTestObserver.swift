import Foundation
import XCTest
import QaseCore

/// XCTest observer that automatically captures test lifecycle events and reports results to Qase.
///
/// Register once before tests run:
/// ```swift
/// QaseTestObserver.register()
/// ```
public final class QaseTestObserver: NSObject, @unchecked Sendable, XCTestObservation {

    /// Programmatic config override set via ``Qase/configure(...)``.
    nonisolated(unsafe) static var configOverride: QaseConfig?

    private var config: QaseConfig = QaseConfig()
    private var batcher: ResultBatcher?
    private var reporter: (any Reporter)?
    private var apiClient: QaseAPIClient?

    nonisolated(unsafe) private static var registered = false

    /// Registers the observer with XCTest. Safe to call multiple times — only registers once.
    public static func register() {
        guard !registered else { return }
        registered = true
        let observer = QaseTestObserver()
        XCTestObservationCenter.shared.addTestObserver(observer)
        QaseLogger.log("QaseTestObserver registered")
    }

    // MARK: - XCTestObservation

    public func testBundleWillStart(_ testBundle: Bundle) {
        // Search for .env and qase.config.json in the source root if available
        let searchPaths: [String] = {
            var paths: [String] = []
            // __XCODE_BUILT_PRODUCTS_DIR_PATHS or SOURCE_ROOT are set by Xcode
            if let sourceRoot = ProcessInfo.processInfo.environment["QASE_PROJECT_DIR"] {
                paths.append(sourceRoot)
            }
            // Walk up from the test bundle to find the project root
            var dir = (testBundle.bundlePath as NSString).deletingLastPathComponent
            for _ in 0..<10 {
                let envPath = (dir as NSString).appendingPathComponent(".env")
                if FileManager.default.fileExists(atPath: envPath) {
                    paths.append(dir)
                    break
                }
                dir = (dir as NSString).deletingLastPathComponent
            }
            return paths
        }()
        config = ConfigLoader().load(overrides: Self.configOverride, searchPaths: searchPaths)

        guard config.mode != .off else {
            QaseLogger.log("Qase reporting is off")
            return
        }

        switch config.mode {
        case .testops:
            guard !config.apiToken.isEmpty, !config.project.isEmpty else {
                QaseLogger.log("Qase testops mode requires API token and project code. Falling back to off.")
                config.mode = .off
                return
            }
            let client = QaseAPIClient(config: config)
            let testOpsReporter = TestOpsReporter(client: client)
            apiClient = client
            reporter = testOpsReporter
            batcher = ResultBatcher(reporter: testOpsReporter, config: config)

            // Create run synchronously (block test start until run is ready)
            let semaphore = DispatchSemaphore(value: 0)
            Task {
                do {
                    try await testOpsReporter.start(config: self.config)
                } catch {
                    QaseLogger.log("Failed to start Qase run: \(error)")
                    self.config.mode = .off
                }
                semaphore.signal()
            }
            semaphore.wait()

        case .report:
            let localReporter = LocalFileReporter()
            reporter = localReporter
            batcher = ResultBatcher(reporter: localReporter, config: config)

            let semaphore = DispatchSemaphore(value: 0)
            Task {
                try? await localReporter.start(config: self.config)
                semaphore.signal()
            }
            semaphore.wait()

        case .off:
            break
        }
    }

    public func testCaseWillStart(_ testCase: XCTestCase) {
        guard config.mode != .off else { return }

        let testID = ObjectIdentifier(testCase)
        Qase.shared.store.initialize(for: testID)

        // Associate test ID with the current thread for step/attachment tracking
        Thread.current.threadDictionary["__qase_test_id__"] = testID
    }

    public func testCase(_ testCase: XCTestCase, didRecord issue: XCTIssue) {
        guard config.mode != .off else { return }

        let testID = ObjectIdentifier(testCase)
        let issueType: IssueInfo.IssueType = switch issue.type {
        case .assertionFailure: .assertionFailure
        case .thrownError: .thrownError
        case .uncaughtException: .uncaughtException
        default: .other
        }

        let info = IssueInfo(
            type: issueType,
            description: issue.compactDescription,
            detailedDescription: issue.detailedDescription,
            sourceFile: issue.sourceCodeContext.location?.fileURL.lastPathComponent,
            sourceLine: issue.sourceCodeContext.location?.lineNumber
        )

        Qase.shared.store.update(for: testID) { metadata in
            metadata.issues.append(info)
        }
    }

    public func testCaseDidFinish(_ testCase: XCTestCase) {
        guard config.mode != .off else { return }

        let testID = ObjectIdentifier(testCase)
        Thread.current.threadDictionary.removeObject(forKey: "__qase_test_id__")

        guard let metadata = Qase.shared.store.consume(for: testID) else { return }

        // Skip ignored tests
        guard !metadata.ignore else { return }

        // Determine status
        let status: TestStatus
        if testCase.testRun?.hasBeenSkipped == true {
            status = .skipped
        } else if metadata.issues.isEmpty {
            status = .passed
        } else if metadata.issues.contains(where: { $0.type == .thrownError || $0.type == .uncaughtException }) {
            status = .invalid
        } else {
            status = .failed
        }

        // Build comment from issues
        let comment: String? = metadata.issues.isEmpty ? nil : metadata.issues.map { issue in
            var msg = issue.description
            if let file = issue.sourceFile, let line = issue.sourceLine {
                msg += " (\(file):\(line))"
            }
            return msg
        }.joined(separator: "\n")

        let elapsed = CFAbsoluteTimeGetCurrent() - metadata.startTime
        let timeMs = Int(elapsed * 1000)

        let result = TestResult(
            caseIDs: metadata.caseIDs,
            status: status,
            timeMs: timeMs,
            comment: comment,
            steps: metadata.steps,
            fields: metadata.fields,
            testName: testCase.name,
            suite: metadata.suite,
            title: metadata.title
        )

        // Add to batcher (fire-and-forget from sync context)
        let testName = testCase.name
        let attachmentsToUpload = metadata.attachments
        let mode = config.mode
        if let batcher {
            let semaphore = DispatchSemaphore(value: 0)
            let client = self.apiClient
            Task {
                do {
                    if mode == .testops, !attachmentsToUpload.isEmpty, let client {
                        let hashes = try await client.uploadAttachments(attachmentsToUpload)
                        var updatedResult = result
                        updatedResult.attachmentHashes = hashes
                        try await batcher.add(updatedResult)
                    } else {
                        try await batcher.add(result)
                    }
                } catch {
                    QaseLogger.log("Failed to report result for \(testName): \(error)")
                }
                semaphore.signal()
            }
            semaphore.wait()
        }
    }

    public func testBundleDidFinish(_ testBundle: Bundle) {
        guard config.mode != .off else { return }

        let semaphore = DispatchSemaphore(value: 0)
        Task {
            do {
                try await self.batcher?.flush()
                try await self.reporter?.finish(config: self.config)
            } catch {
                QaseLogger.log("Failed to finish Qase reporting: \(error)")
            }
            semaphore.signal()
        }
        semaphore.wait()
    }
}
