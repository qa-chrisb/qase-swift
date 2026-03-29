import XCTest
import QaseCore

extension XCTestCase {
    /// Links this test to a Qase test case by ID.
    public func qase(id: Int) {
        Qase.shared.store.update(for: ObjectIdentifier(self)) { metadata in
            metadata.caseIDs.append(id)
        }
    }

    /// Links this test to multiple Qase test cases.
    public func qase(ids: [Int]) {
        Qase.shared.store.update(for: ObjectIdentifier(self)) { metadata in
            metadata.caseIDs.append(contentsOf: ids)
        }
    }

    /// Overrides the test title reported to Qase.
    public func qase(title: String) {
        Qase.shared.store.update(for: ObjectIdentifier(self)) { metadata in
            metadata.title = title
        }
    }

    /// Sets the suite path for this test in Qase (e.g. "Auth/Login").
    public func qase(suite: String) {
        Qase.shared.store.update(for: ObjectIdentifier(self)) { metadata in
            metadata.suite = suite
        }
    }

    /// Sets custom field values for the Qase result.
    public func qase(fields: [String: String]) {
        Qase.shared.store.update(for: ObjectIdentifier(self)) { metadata in
            metadata.fields.merge(fields) { _, new in new }
        }
    }

    /// Excludes this test from Qase reporting (test still runs).
    public func qase(ignore: Bool = true) {
        Qase.shared.store.update(for: ObjectIdentifier(self)) { metadata in
            metadata.ignore = ignore
        }
    }
}
