import Foundation
import Security

/// Speichert den Music-Assistant-Access-Token in der macOS-Keychain statt in
/// UserDefaults — der Token ist ein Secret und darf nicht im Klartext landen.
public struct KeychainTokenStore: Sendable {
    public enum KeychainError: Error, CustomStringConvertible, Sendable {
        case unexpectedStatus(OSStatus)

        public var description: String {
            switch self {
            case .unexpectedStatus(let status):
                return "Keychain-Fehler (\(status))"
            }
        }
    }

    private let service: String
    private let account = "mass-token"

    public init(service: String = "org.fire-devils.MAMenubar") {
        self.service = service
    }

    public func load() throws -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
        guard let data = result as? Data, let token = String(data: data, encoding: .utf8) else { return nil }
        return token
    }

    public func save(_ token: String) throws {
        let data = Data(token.utf8)
        let query = baseQuery()
        let updateStatus = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)

        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError.unexpectedStatus(addStatus) }
        } else {
            guard updateStatus == errSecSuccess else { throw KeychainError.unexpectedStatus(updateStatus) }
        }
    }

    public func delete() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
