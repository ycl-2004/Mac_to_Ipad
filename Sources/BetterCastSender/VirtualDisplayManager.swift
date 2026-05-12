import Foundation
import CoreGraphics
import VirtualDisplayLib

/// Swift wrapper for the Objective-C VirtualDisplay functionality
/// Uses private CoreGraphics APIs to create virtual displays
class VirtualDisplayManager {
    enum DisplayPlacement: String, CaseIterable, Identifiable {
        case right
        case left
        case above
        case below

        var id: String { rawValue }

        var title: String {
            switch self {
            case .right: return "Right"
            case .left: return "Left"
            case .above: return "Above"
            case .below: return "Below"
            }
        }
    }

    
    struct Resolution: Hashable {
        let width: Int
        let height: Int
        let ppi: Int
        let hiDPI: Bool
        let name: String
    }
    
    static let receiverBestFitResolution = Resolution(width: 2688, height: 1868, ppi: 220, hiDPI: true, name: "1344 x 934 HiDPI (Best Fit)")

    static let defaultResolutions: [Resolution] = [
        receiverBestFitResolution,
        Resolution(width: 1280, height: 720, ppi: 92, hiDPI: false, name: "1280 x 720 (HD)"),
        Resolution(width: 1920, height: 1080, ppi: 102, hiDPI: false, name: "1920 x 1080 (FHD)"),
        Resolution(width: 1920, height: 1200, ppi: 113, hiDPI: false, name: "1920 x 1200 (16:10)"),
        Resolution(width: 2560, height: 1440, ppi: 109, hiDPI: false, name: "2560 x 1440 (2K)"),
        Resolution(width: 2560, height: 1600, ppi: 227, hiDPI: true, name: "2560 x 1600 (16:10)"),
        Resolution(width: 3840, height: 2160, ppi: 163, hiDPI: false, name: "3840 x 2160 (4K)"),
        Resolution(width: 1440, height: 900, ppi: 127, hiDPI: false, name: "1440 x 900 (16:10)"),
    ]
    
    private static var nextSerialNum: UInt32 = 1

    private var activeDisplay: Any?
    private(set) var displayID: CGDirectDisplayID?
    var onDisplayBoundsChanged: ((CGRect) -> Void)?
    private let serialNum: UInt32

    init() {
        self.serialNum = VirtualDisplayManager.nextSerialNum
        VirtualDisplayManager.nextSerialNum += 1
    }
    
    /// Creates a virtual display with the specified resolution
    /// - Returns: The CGDirectDisplayID of the created virtual display, or nil if creation failed
    func createDisplay(resolution: Resolution, placement: DisplayPlacement = .right) -> CGDirectDisplayID? {
        return createDisplay(
            width: resolution.width,
            height: resolution.height,
            ppi: resolution.ppi,
            hiDPI: resolution.hiDPI,
            name: resolution.name,
            placement: placement
        )
    }
    
    /// Creates a virtual display with custom parameters
    func createDisplay(width: Int, height: Int, ppi: Int, hiDPI: Bool, name: String, placement: DisplayPlacement = .right) -> CGDirectDisplayID? {
        // Call the Objective-C function
        guard let display = createVirtualDisplay(
            Int32(width),
            Int32(height),
            Int32(ppi),
            hiDPI,
            name,
            serialNum
        ) else {
            LogManager.shared.log("VirtualDisplayManager: Failed to create virtual display")
            return nil
        }
        
        activeDisplay = display
        
        // Get the display ID from the created virtual display
        // The CGVirtualDisplay object has a displayID property
        if let displayIDValue = (display as AnyObject).value(forKey: "displayID") as? UInt32 {
            self.displayID = displayIDValue
            LogManager.shared.log("VirtualDisplayManager: Created virtual display with ID \(displayIDValue)")
            schedulePlacement(for: displayIDValue, placement: placement)
            return displayIDValue
        }
        
        LogManager.shared.log("VirtualDisplayManager: Created display but couldn't get ID")
        return nil
    }
    
    /// Destroys the currently active virtual display
    func destroyDisplay() {
        activeDisplay = nil
        displayID = nil
        LogManager.shared.log("VirtualDisplayManager: Destroyed virtual display")
    }
    
    deinit {
        destroyDisplay()
    }

    private func schedulePlacement(for displayID: CGDirectDisplayID, placement: DisplayPlacement, attempt: Int = 1) {
        let delays: [TimeInterval] = [0.25, 0.75, 1.5, 3.0, 5.0]
        guard attempt <= delays.count else { return }

        let delay = delays[attempt - 1]
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.displayID == displayID else { return }

            if self.placeDisplay(displayID, relativeToBuiltIn: placement) {
                LogManager.shared.log("VirtualDisplayManager: Placed display \(displayID) \(placement.rawValue) of the built-in display (attempt \(attempt))")
            } else {
                LogManager.shared.log("VirtualDisplayManager: Placement attempt \(attempt) failed for display \(displayID)")
            }
            self.schedulePlacement(for: displayID, placement: placement, attempt: attempt + 1)
        }
    }

    private func placeDisplay(_ displayID: CGDirectDisplayID, relativeToBuiltIn placement: DisplayPlacement) -> Bool {
        let displayBounds = CGDisplayBounds(displayID)
        guard displayBounds.width > 0, displayBounds.height > 0 else {
            return false
        }

        let referenceDisplayID = builtInDisplayID() ?? CGMainDisplayID()
        let referenceBounds = CGDisplayBounds(referenceDisplayID)
        guard referenceBounds.width > 0, referenceBounds.height > 0 else {
            return false
        }

        let occupiedDisplays = onlineDisplayIDs().filter { $0 != displayID }
        var targetOrigin = targetOrigin(
            for: displayBounds.size,
            beside: referenceBounds,
            avoiding: occupiedDisplays.map { CGDisplayBounds($0) },
            placement: placement
        )

        let targetRect = CGRect(origin: targetOrigin, size: displayBounds.size)
        if occupiedDisplays.contains(where: { CGDisplayBounds($0).intersects(targetRect) }) {
            targetOrigin = fallbackOuterOrigin(
                for: displayBounds.size,
                beside: referenceBounds,
                avoiding: occupiedDisplays.map { CGDisplayBounds($0) },
                placement: placement
            )
        }

        guard applyDisplayOrigin(displayID, targetOrigin) else {
            return false
        }

        let updatedBounds = CGDisplayBounds(displayID)
        if updatedBounds.width > 0, updatedBounds.height > 0 {
            onDisplayBoundsChanged?(updatedBounds)
        } else {
            onDisplayBoundsChanged?(CGRect(origin: targetOrigin, size: displayBounds.size))
        }

        return true
    }

    private func applyDisplayOrigin(_ displayID: CGDirectDisplayID, _ origin: CGPoint) -> Bool {
        let x = Int32(origin.x.rounded())
        let y = Int32(origin.y.rounded())

        if configureDisplayOrigin(displayID, x: x, y: y, option: .permanently) {
            return true
        }

        LogManager.shared.log("VirtualDisplayManager: Permanent placement failed for \(displayID), retrying for current session")
        return configureDisplayOrigin(displayID, x: x, y: y, option: .forSession)
    }

    private func configureDisplayOrigin(
        _ displayID: CGDirectDisplayID,
        x: Int32,
        y: Int32,
        option: CGConfigureOption
    ) -> Bool {
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success, let config else {
            LogManager.shared.log("VirtualDisplayManager: Failed to begin display configuration")
            return false
        }

        let configureError = CGConfigureDisplayOrigin(
            config,
            displayID,
            x,
            y
        )
        guard configureError == .success else {
            CGCancelDisplayConfiguration(config)
            LogManager.shared.log("VirtualDisplayManager: Failed to configure display origin for \(displayID): \(configureError.rawValue)")
            return false
        }

        let completeError = CGCompleteDisplayConfiguration(config, option)
        guard completeError == .success else {
            LogManager.shared.log("VirtualDisplayManager: Failed to complete display configuration for \(displayID): \(completeError.rawValue)")
            return false
        }

        return true
    }

    private func targetOrigin(
        for displaySize: CGSize,
        beside referenceBounds: CGRect,
        avoiding occupiedBounds: [CGRect],
        placement: DisplayPlacement
    ) -> CGPoint {
        let proposed: CGPoint
        switch placement {
        case .right:
            proposed = CGPoint(x: referenceBounds.maxX, y: referenceBounds.minY)
        case .left:
            proposed = CGPoint(x: referenceBounds.minX - displaySize.width, y: referenceBounds.minY)
        case .above:
            proposed = CGPoint(x: referenceBounds.minX, y: referenceBounds.minY - displaySize.height)
        case .below:
            proposed = CGPoint(x: referenceBounds.minX, y: referenceBounds.maxY)
        }

        let proposedRect = CGRect(origin: proposed, size: displaySize)
        if !occupiedBounds.contains(where: { $0.intersects(proposedRect) }) {
            return proposed
        }

        return fallbackOuterOrigin(
            for: displaySize,
            beside: referenceBounds,
            avoiding: occupiedBounds,
            placement: placement
        )
    }

    private func fallbackOuterOrigin(
        for displaySize: CGSize,
        beside referenceBounds: CGRect,
        avoiding occupiedBounds: [CGRect],
        placement: DisplayPlacement
    ) -> CGPoint {
        switch placement {
        case .right:
            let rightMostX = occupiedBounds.map(\.maxX).max() ?? referenceBounds.maxX
            return CGPoint(x: rightMostX, y: referenceBounds.minY)
        case .left:
            let leftMostX = occupiedBounds.map(\.minX).min() ?? referenceBounds.minX
            return CGPoint(x: leftMostX - displaySize.width, y: referenceBounds.minY)
        case .above:
            let topMostY = occupiedBounds.map(\.minY).min() ?? referenceBounds.minY
            return CGPoint(x: referenceBounds.minX, y: topMostY - displaySize.height)
        case .below:
            let bottomMostY = occupiedBounds.map(\.maxY).max() ?? referenceBounds.maxY
            return CGPoint(x: referenceBounds.minX, y: bottomMostY)
        }
    }

    private func builtInDisplayID() -> CGDirectDisplayID? {
        onlineDisplayIDs().first { CGDisplayIsBuiltin($0) != 0 }
    }

    private func onlineDisplayIDs() -> [CGDirectDisplayID] {
        var displayCount: UInt32 = 0
        var displays = [CGDirectDisplayID](repeating: 0, count: 16)

        guard CGGetOnlineDisplayList(UInt32(displays.count), &displays, &displayCount) == .success else {
            return []
        }

        return Array(displays.prefix(Int(displayCount)))
    }
}
