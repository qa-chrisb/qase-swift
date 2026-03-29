import Foundation
import Testing
import QaseCore
@testable import QaseXCTest

@Suite("MetadataStore")
struct MetadataStoreTests {

    @Test("initialize creates entry with start time")
    func initialize() {
        let store = MetadataStore()
        let id = ObjectIdentifier(NSObject())

        store.initialize(for: id)
        let metadata = store.read(for: id)
        #expect(metadata != nil)
        #expect(metadata?.caseIDs.isEmpty == true)
        #expect((metadata?.startTime ?? 0) > 0)
    }

    @Test("update mutates metadata in place")
    func update() {
        let store = MetadataStore()
        let id = ObjectIdentifier(NSObject())

        store.initialize(for: id)
        store.update(for: id) { $0.caseIDs = [42, 99] }
        store.update(for: id) { $0.title = "My Test" }

        let metadata = store.read(for: id)
        #expect(metadata?.caseIDs == [42, 99])
        #expect(metadata?.title == "My Test")
    }

    @Test("consume removes entry and returns it")
    func consume() {
        let store = MetadataStore()
        let id = ObjectIdentifier(NSObject())

        store.initialize(for: id)
        store.update(for: id) { $0.caseIDs = [1] }

        let consumed = store.consume(for: id)
        #expect(consumed?.caseIDs == [1])
        #expect(store.read(for: id) == nil)
    }

    @Test("update on non-existent key is a no-op")
    func updateMissing() {
        let store = MetadataStore()
        let id = ObjectIdentifier(NSObject())

        // Should not crash
        store.update(for: id) { $0.caseIDs = [1] }
        #expect(store.read(for: id) == nil)
    }

    @Test("concurrent access is safe")
    func concurrentAccess() async {
        let store = MetadataStore()
        let obj = NSObject()
        let id = ObjectIdentifier(obj)
        store.initialize(for: id)

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    store.update(for: id) { $0.caseIDs.append(i) }
                }
            }
        }

        let metadata = store.read(for: id)
        #expect(metadata?.caseIDs.count == 100)
    }
}
