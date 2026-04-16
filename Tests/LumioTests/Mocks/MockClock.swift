import Foundation
@testable import Lumio

final class MockClock: ClockProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var _currentDate: Date = Date()

    var currentDate: Date {
        get { lock.withLock { _currentDate } }
        set { lock.withLock { _currentDate = newValue } }
    }

    func now() -> Date {
        currentDate
    }
}
