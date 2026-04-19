import Foundation
import Security

#if os(iOS)
import UIKit
#endif

protocol DeviceIdentifying: Sendable {
    func identifier() -> String
}

/// Stable per-user identifier.
///
/// Prefers a Keychain-persisted UUID so the ID survives app reinstalls on the
/// same device. First-launch seeds the Keychain with the current IDFV rather
/// than a fresh UUID, so users upgrading from older SDK versions keep the same
/// identifier — their historical events stay joined to the same user.
///
/// Fallback chain: Keychain → IDFV → UserDefaults UUID.
struct DeviceIdentifier: DeviceIdentifying {
    private let keychainService = "com.lumio.sdk"
    private let keychainAccount = "device_id"
    private let userDefaultsKey = "com.lumio.device_id"

    func identifier() -> String {
        if let existing = keychainRead() {
            return existing
        }
        let seed = currentIDFV() ?? persistedUUID()
        keychainWrite(seed)
        return seed
    }

    private func currentIDFV() -> String? {
        #if os(iOS)
        return UIDevice.current.identifierForVendor?.uuidString
        #else
        return nil
        #endif
    }

    private func persistedUUID() -> String {
        if let existing = UserDefaults.standard.string(forKey: userDefaultsKey) {
            return existing
        }
        let new = UUID().uuidString
        UserDefaults.standard.set(new, forKey: userDefaultsKey)
        return new
    }

    private func keychainRead() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        guard status == errSecSuccess,
              let data = out as? Data,
              let str = String(data: data, encoding: .utf8) else {
            return nil
        }
        return str
    }

    private func keychainWrite(_ value: String) {
        let data = Data(value.utf8)
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let attrs: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data,
        ]
        SecItemAdd(attrs as CFDictionary, nil)
    }
}
