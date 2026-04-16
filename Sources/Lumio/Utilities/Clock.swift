import Foundation

/// Protocol for timestamp generation, allowing mock injection in tests.
protocol ClockProtocol: Sendable {
    func now() -> Date
}

/// Real clock using the system time.
struct SystemClock: ClockProtocol {
    func now() -> Date { Date() }
}
