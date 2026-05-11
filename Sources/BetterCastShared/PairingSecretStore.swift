import Foundation
import Security

public protocol PairingSecretStoring {
    func loadSecret() throws -> Data?
    func saveSecret(_ secret: Data) throws
    func deleteSecret() throws
}

public enum PairingSecretStoreError: Error, Equatable {
    case unhandledStatus(OSStatus)
}

public final class KeychainPairingSecretStore: PairingSecretStoring {
    private let service: String
    private let account: String

    public init(
        service: String = PrivateBetterCastConstants.appGroupKeychainService,
        account: String = PrivateBetterCastConstants.pairingSecretAccount
    ) {
        self.service = service
        self.account = account
    }

    public func loadSecret() throws -> Data? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw PairingSecretStoreError.unhandledStatus(status)
        }
        return item as? Data
    }

    public func saveSecret(_ secret: Data) throws {
        try deleteSecret()

        var query = baseQuery()
        query[kSecValueData as String] = secret
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw PairingSecretStoreError.unhandledStatus(status)
        }
    }

    public func deleteSecret() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw PairingSecretStoreError.unhandledStatus(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
