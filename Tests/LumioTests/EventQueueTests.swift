import XCTest
@testable import Lumio

final class EventQueueTests: XCTestCase {

    private func makeQueue(
        threshold: Int = 3,
        flushInterval: TimeInterval = 60,
        networkClient: MockNetworkClient = MockNetworkClient()
    ) -> (EventQueue, MockNetworkClient) {
        let config = Configuration(
            appKey: "lm_test_key",
            endpoint: URL(string: "http://localhost:8080")!,
            flushInterval: flushInterval,
            flushThreshold: threshold
        )
        let store = PersistentStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let queue = EventQueue(config: config, userID: "test-user", networkClient: networkClient, persistentStore: store)
        return (queue, networkClient)
    }

    private func makeEvent(name: String = "step") -> TrackEvent {
        TrackEvent(
            eventName: name,
            timestamp: "2026-04-15T10:30:00.000Z",
            propertiesJSON: "{\"step_name\":\"test\",\"step_order\":1}"
        )
    }

    func testManualFlush() async {
        let (queue, mock) = makeQueue()

        await queue.enqueue(makeEvent())
        await queue.enqueue(makeEvent(name: "paywall_view"))

        let beforeFlush = await mock.sentPayloads
        XCTAssertTrue(beforeFlush.isEmpty)

        await queue.flush()

        let afterFlush = await mock.sentPayloads
        XCTAssertEqual(afterFlush.count, 1)
        XCTAssertEqual(afterFlush[0].events.count, 2)
        XCTAssertEqual(afterFlush[0].userID, "test-user")
    }

    func testThresholdFlush() async throws {
        let (queue, mock) = makeQueue(threshold: 2)

        await queue.enqueue(makeEvent())
        await queue.enqueue(makeEvent())

        try await Task.sleep(nanoseconds: 200_000_000)

        let payloads = await mock.sentPayloads
        XCTAssertEqual(payloads.count, 1)
        XCTAssertEqual(payloads[0].events.count, 2)
    }

    func testFailedSendsArePersisted() async {
        let mock = MockNetworkClient()
        await mock.setFailure()
        let (queue, _) = makeQueue(networkClient: mock)

        await queue.enqueue(makeEvent())
        await queue.flush()

        let payloads = await mock.sentPayloads
        XCTAssertEqual(payloads.count, 1)
    }

    func testEmptyFlush() async {
        let (queue, mock) = makeQueue()
        await queue.flush()
        let payloads = await mock.sentPayloads
        XCTAssertTrue(payloads.isEmpty)
    }
}
