import Foundation

/// SDK configuration passed during initialization.
public struct Configuration: Sendable {
    public let appKey: String
    public let endpoint: URL
    public let flushInterval: TimeInterval
    public let flushThreshold: Int
    /// Auto-detected at configure time. True for debug builds (Xcode run) and
    /// TestFlight/sandbox installs; false for App Store production. Sandbox
    /// events are tagged on the backend so they don't pollute production
    /// analytics and don't count toward your event limit.
    public let isSandbox: Bool

    public init(
        appKey: String,
        endpoint: URL = URL(string: "https://api.trylumio.app")!,
        flushInterval: TimeInterval = 30,
        flushThreshold: Int = 30,
        isSandbox: Bool = false
    ) {
        self.appKey = appKey
        self.endpoint = endpoint
        self.flushInterval = flushInterval
        self.flushThreshold = flushThreshold
        self.isSandbox = isSandbox
    }
}
