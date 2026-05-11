import XCTest
@testable import BetterCastShared

private final class InMemoryPairingSecretStore: PairingSecretStoring {
    private var secret: Data?

    func loadSecret() throws -> Data? {
        secret
    }

    func saveSecret(_ secret: Data) throws {
        self.secret = secret
    }

    func deleteSecret() throws {
        secret = nil
    }
}

final class PairingSecretStoreTests: XCTestCase {
    func testSecretStoreProtocolCanSaveLoadAndDelete() throws {
        let store = InMemoryPairingSecretStore()
        let secret = PairingAuthenticator.normalizedSecret(from: "123456")

        XCTAssertNil(try store.loadSecret())
        try store.saveSecret(secret)
        XCTAssertEqual(try store.loadSecret(), secret)
        try store.deleteSecret()
        XCTAssertNil(try store.loadSecret())
    }
}
