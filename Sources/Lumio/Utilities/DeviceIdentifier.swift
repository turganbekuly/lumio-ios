import Foundation

/// Protocol for device identification, allowing mock injection in tests.
protocol DeviceIdentifying: Sendable {
    func identifier() -> String
}

/// Uses IDFV on iOS, falls back to a persistent UUID.
struct DeviceIdentifier: DeviceIdentifying {
    func identifier() -> String {
        #if os(iOS)
        if let idfv = UIDevice.current.identifierForVendor?.uuidString {
            return idfv
        }
        #endif
        return persistedIdentifier()
    }

    private func persistedIdentifier() -> String {
        let key = "com.lumio.device_id"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let newID = UUID().uuidString
        UserDefaults.standard.set(newID, forKey: key)
        return newID
    }
}
