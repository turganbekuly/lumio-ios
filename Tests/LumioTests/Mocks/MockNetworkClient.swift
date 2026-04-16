import Foundation
@testable import Lumio

actor MockNetworkClient: NetworkClientProtocol {
    private var _sentPayloads: [TrackPayload] = []
    var shouldSucceed: Bool = true

    var sentPayloads: [TrackPayload] {
        _sentPayloads
    }

    func setFailure() {
        shouldSucceed = false
    }

    func send(payload: TrackPayload, config: Configuration) async -> Bool {
        _sentPayloads.append(payload)
        return shouldSucceed
    }
}
