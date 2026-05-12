import Foundation

public enum PrivateBetterCastConstants {
    public static let protocolVersion: UInt8 = 1
    public static let serviceType = "_yc-cast._tcp"
    public static let senderBundleID = "com.yichen.yccast.sender"
    public static let receiverBundleID = "com.yichen.yccast.receiver.ios"
    public static let appGroupKeychainService = "com.yichen.yccast.pairing"
    public static let pairingSecretAccount = "pairing-secret-v1"
}
