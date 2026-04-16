import Foundation

/// SDK configuration passed during initialization.
public struct Configuration: Sendable {
    public let appKey: String
    public let endpoint: URL
    public let flushInterval: TimeInterval
    public let flushThreshold: Int

    public init(
        appKey: String,
        endpoint: URL = URL(string: "https://api.trylumio.dev")!,
        flushInterval: TimeInterval = 30,
        flushThreshold: Int = 30
    ) {
        self.appKey = appKey
        self.endpoint = endpoint
        self.flushInterval = flushInterval
        self.flushThreshold = flushThreshold
    }
}
