import XCTest
@testable import Lumio

final class NetworkClientTests: XCTestCase {

    func testMockRecordsPayloads() async {
        let mock = MockNetworkClient()
        let config = Configuration(
            appKey: "lm_test_key",
            endpoint: URL(string: "http://localhost:8080")!
        )
        let payload = TrackPayload(
            appID: "lm_test_key",
            userID: "test-user",
            events: [
                TrackEvent(
                    eventName: "step",
                    timestamp: "2026-04-15T10:30:00.000Z",
                    propertiesJSON: "{}"
                )
            ]
        )

        let result = await mock.send(payload: payload, config: config)
        XCTAssertTrue(result)

        let payloads = await mock.sentPayloads
        XCTAssertEqual(payloads.count, 1)
    }

    func testMockSimulatesFailure() async {
        let mock = MockNetworkClient()
        await mock.setFailure()

        let config = Configuration(
            appKey: "lm_test_key",
            endpoint: URL(string: "http://localhost:8080")!
        )
        let payload = TrackPayload(
            appID: "lm_test_key",
            userID: "test-user",
            events: []
        )

        let result = await mock.send(payload: payload, config: config)
        XCTAssertFalse(result)
    }
}
