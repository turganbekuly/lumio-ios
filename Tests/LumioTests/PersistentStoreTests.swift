import XCTest
@testable import Lumio

final class PersistentStoreTests: XCTestCase {

    private func makeStore() -> PersistentStore {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return PersistentStore(directory: dir)
    }

    private func makePayload() -> TrackPayload {
        TrackPayload(
            appID: "lm_test_key",
            userID: "test-user",
            events: [
                TrackEvent(
                    eventName: "step",
                    timestamp: "2026-04-15T10:30:00.000Z",
                    propertiesJSON: "{\"step_name\":\"welcome\",\"step_order\":1}"
                )
            ]
        )
    }

    func testSaveAndLoad() async {
        let store = makeStore()

        await store.save(payload: makePayload())
        let loaded = await store.loadAll()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].userID, "test-user")
        XCTAssertEqual(loaded[0].events.count, 1)
        XCTAssertEqual(loaded[0].events[0].eventName, "step")
    }

    func testRemoveAll() async {
        let store = makeStore()

        await store.save(payload: makePayload())
        await store.save(payload: makePayload())

        let before = await store.loadAll()
        XCTAssertEqual(before.count, 2)

        await store.removeAll()

        let after = await store.loadAll()
        XCTAssertTrue(after.isEmpty)
    }

    func testEmptyDirectory() async {
        let store = makeStore()
        let loaded = await store.loadAll()
        XCTAssertTrue(loaded.isEmpty)
    }
}
