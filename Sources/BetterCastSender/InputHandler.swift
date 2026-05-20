import Foundation
import CoreGraphics

class InputHandler {
    static let shared = InputHandler()

    // Per-connection display bounds for multi-display routing
    private var displayBoundsMap: [UUID: CGRect] = [:]

    func updateDisplayBounds(bounds: CGRect, for connectionId: UUID) {
        displayBoundsMap[connectionId] = bounds
        LogManager.shared.log("InputHandler: Updated bounds for connection \(connectionId.uuidString.prefix(8)): \(bounds)")
    }

    func removeDisplayBounds(for connectionId: UUID) {
        displayBoundsMap.removeValue(forKey: connectionId)
    }

    func getDisplayBounds(for connectionId: UUID) -> CGRect {
        return displayBoundsMap[connectionId] ?? .zero
    }

    func removeAllDisplayBounds() {
        displayBoundsMap.removeAll()
    }
}
