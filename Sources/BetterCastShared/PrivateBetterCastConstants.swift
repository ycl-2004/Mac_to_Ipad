import Foundation

public enum PrivateBetterCastConstants {
    public static let protocolVersion: UInt8 = 1
    public static let serviceType = "_yc-bettercast._tcp"
    public static let senderBundleID = "com.yichen.privatebettercast.sender"
    public static let receiverBundleID = "com.yichen.privatebettercast.receiver.ios"
    public static let appGroupKeychainService = "com.yichen.privatebettercast.pairing"
    public static let pairingSecretAccount = "pairing-secret-v1"
}
