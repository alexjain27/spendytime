import Foundation
import Security

enum KeychainStore {
    private static let service = "com.alexjain.spendytime"
    private static let account = "db-key"

    static func loadOrCreateKey() -> Data? {
        if let existing = loadKey() {
            return existing
        }
        guard let newKey = generateKey() else {
            return nil
        }
        if saveKey(newKey) {
            return newKey
        }
        return nil
    }

    private static func loadKey() -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else {
            return nil
        }
        return item as? Data
    }

    private static func saveKey(_ key: Data) -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: key
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            return updateKey(key)
        }
        return status == errSecSuccess
    }

    private static func updateKey(_ key: Data) -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        let attributes: [CFString: Any] = [
            kSecValueData: key
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        return status == errSecSuccess
    }

    private static func generateKey() -> Data? {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            return nil
        }
        return Data(bytes)
    }
}
