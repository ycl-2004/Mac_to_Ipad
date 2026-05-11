# Private Mac-iPad BetterCast Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a private Apple-only BetterCast fork where a Mac creates an extended virtual display, streams that display to a paired iPad, and accepts iPad touch/mouse/keyboard input only from the authenticated paired iPad.

**Architecture:** Keep the existing Mac sender and iOS receiver pipeline, but remove active non-Apple surfaces from the product path. Add a shared pairing/authentication layer used by both targets before video streaming or remote input is allowed. Force the private version onto a TCP-only Apple P2P/AWDL-first path, with no Mac receiver auto-start, no Android/Windows/Linux UI paths, no unauthenticated input handling, and no automatic external update/report flows.

**Tech Stack:** Swift 6, SwiftPM, SwiftUI/AppKit on macOS, UIKit on iOS/iPadOS, Network.framework, ScreenCaptureKit, VideoToolbox, CoreGraphics virtual display private APIs, CryptoKit HMAC-SHA256, Keychain via Security.framework.

---

## Scope

In scope:
- Mac sender creates an extended virtual display by default.
- iPad receiver displays that virtual display.
- iPad touch gestures, iPad-connected pointer, and iPad keyboard events can control the streamed Mac display after authentication.
- Pairing uses a shared secret saved locally on both devices.
- Mac accepts input only after a successful authenticated session.
- Apple-only P2P/AWDL is the default connection path.
- TCP is the only supported stream protocol for the private first version.

Out of scope for this private first version:
- Windows receiver.
- Linux receiver.
- Android receiver and ADB flows.
- Mac receiver mode.
- UDP video transport.
- Multi-iPad support.
- Internet/remote access.
- Public distribution/notarized release packaging.

## File Structure

Create:
- `Sources/BetterCastShared/PairingAuthenticator.swift`  
  Shared nonce, HMAC, session key, and authenticated envelope logic.
- `Sources/BetterCastShared/PairingSecretStore.swift`  
  Keychain-backed secret persistence for macOS and iOS.
- `Sources/BetterCastShared/PrivateBetterCastConstants.swift`  
  Private Bonjour service type, protocol version, magic strings, and feature flags.
- `Tests/BetterCastSharedTests/PairingAuthenticatorTests.swift`  
  Unit tests for handshake success/failure and envelope verification.
- `Tests/BetterCastSharedTests/PairingSecretStoreTests.swift`  
  Unit tests around store abstraction using an in-memory test store.

Modify:
- `Package.swift`  
  Add `BetterCastShared` target, link CryptoKit/Security as needed, and add shared tests.
- `BetterCastSender-Info.plist`  
  Change bundle ID to a private ID so TCC permissions do not overlap with the public app.
- `Sources/BetterCastReceiverIOS/Info.plist`  
  Change bundle ID and Bonjour service type to the private Apple-only service.
- `Sources/BetterCastSender/Constants.swift`  
  Remove public service constants from active use or redirect to private constants.
- `Sources/BetterCastReceiverIOS/Constants.swift`  
  Redirect active Bonjour constants to private constants.
- `Sources/BetterCastSender/BetterCastSenderApp.swift`  
  Disable Mac receiver auto-start, disable update check, hide non-Apple UI paths, force Extended Display/TCP/P2P defaults, add pairing UI, and require authenticated pipelines before streaming/input.
- `Sources/BetterCastSender/InputHandler.swift`  
  Keep CGEvent injection, but only behind authenticated session handling.
- `Sources/BetterCastReceiverIOS/NetworkListenerIOS.swift`  
  Remove Wi-Fi listener and UDP listener from active startup, add handshake before decoding/sending input.
- `Sources/BetterCastReceiverIOS/ViewController.swift`  
  Add pairing-code setup UI, remove public download link, block network start until a pairing secret exists.
- `Sources/BetterCastReceiverIOS/VideoRendererViewIOS.swift`  
  Keep touch/cursor/scroll gestures; add keyboard/pointer support if missing during implementation verification.
- `Sources/BetterCastSender/LogManager.swift`  
  Remove automatic GitHub release check and Report Issue URL path from private app.
- `README.md`  
  Replace public cross-platform install guidance with private Mac+iPad build/use notes.

Leave present but inactive for now:
- `Sources/BetterCastReceiverDesktop/**`
- `Sources/BetterCastReceiverAndroid/**`
- `Sources/BetterCastSender/ReceiverMode.swift`
- `Sources/BetterCastSender/ReceiverNetworkListener.swift`

These can be deleted in a later cleanup after the private Mac+iPad path is verified.

---

## Design Decisions

1. **Authentication before streaming:** The Mac must not start `startPipeline(for:)` until the receiver proves it knows the shared pairing secret.
2. **Authentication before input:** The Mac must ignore all non-heartbeat input events unless the connection has an authenticated session.
3. **TCP-only first version:** Disable UDP because current UDP packets are unauthenticated and easier to spoof on local networks.
4. **P2P-first Apple-only service:** Use a private Bonjour type such as `_yc-bettercast._tcp` and advertise only the iPad P2P/AWDL listener by default.
5. **Accessibility remains required:** iPad-originated control of the Mac display requires `CGEvent` injection, so Accessibility is a necessary permission. The safety improvement is strict pairing, not removal of Accessibility.
6. **No public auto-update/report flows:** A private fork should not query GitHub releases automatically or prefill logs into external GitHub issue URLs.

---

## Task 1: Add Shared Pairing And Authentication Core

**Files:**
- Create: `Sources/BetterCastShared/PrivateBetterCastConstants.swift`
- Create: `Sources/BetterCastShared/PairingAuthenticator.swift`
- Create: `Sources/BetterCastShared/PairingSecretStore.swift`
- Create: `Tests/BetterCastSharedTests/PairingAuthenticatorTests.swift`
- Create: `Tests/BetterCastSharedTests/PairingSecretStoreTests.swift`
- Modify: `Package.swift`

- [ ] **Step 1: Add `BetterCastShared` target to `Package.swift`**

Expected structure:

```swift
.target(
    name: "BetterCastShared",
    linkerSettings: [
        .linkedFramework("CryptoKit"),
        .linkedFramework("Security")
    ]
)
```

Add `BetterCastShared` as a dependency of `BetterCastSender` and `BetterCastReceiverIOS`.

- [ ] **Step 2: Add private constants**

Create `Sources/BetterCastShared/PrivateBetterCastConstants.swift`:

```swift
import Foundation

public enum PrivateBetterCastConstants {
    public static let protocolVersion: UInt8 = 1
    public static let serviceType = "_yc-bettercast._tcp"
    public static let senderBundleID = "com.yichen.privatebettercast.sender"
    public static let receiverBundleID = "com.yichen.privatebettercast.receiver.ios"
    public static let appGroupKeychainService = "com.yichen.privatebettercast.pairing"
    public static let pairingSecretAccount = "pairing-secret-v1"
}
```

- [ ] **Step 3: Write failing tests for HMAC handshake**

Create tests covering:
- Same secret + same nonces authenticates.
- Different secret fails.
- Tampered receiver proof fails.
- Derived session key is stable for same inputs and different for different nonces.

Run:

```bash
swift test --filter PairingAuthenticatorTests
```

Expected: FAIL because the implementation does not exist yet.

- [ ] **Step 4: Implement `PairingAuthenticator`**

Use CryptoKit HMAC-SHA256. Required API shape:

```swift
public struct PairingAuthenticator {
    public static func randomNonce() -> Data
    public static func normalizedSecret(from userInput: String) -> Data
    public static func receiverProof(secret: Data, senderNonce: Data, receiverNonce: Data) -> Data
    public static func senderProof(secret: Data, senderNonce: Data, receiverNonce: Data) -> Data
    public static func deriveSessionKey(secret: Data, senderNonce: Data, receiverNonce: Data) -> Data
    public static func constantTimeEquals(_ lhs: Data, _ rhs: Data) -> Bool
}
```

- [ ] **Step 5: Add authenticated envelope tests**

Test:
- Envelope verifies with correct session key.
- Envelope fails with wrong key.
- Envelope fails after payload tampering.
- Envelope fails after sequence tampering.

- [ ] **Step 6: Implement authenticated envelope**

Required API shape:

```swift
public struct AuthenticatedEnvelope: Codable {
    public let sequence: UInt64
    public let payload: Data
    public let mac: Data
}
```

MAC input should include domain separation, sequence, and payload bytes.

- [ ] **Step 7: Run shared tests**

Run:

```bash
swift test --filter BetterCastSharedTests
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add Package.swift Sources/BetterCastShared Tests/BetterCastSharedTests
git commit -m "feat: add private pairing authentication core"
```

---

## Task 2: Add Pairing Secret Storage And Setup State

**Files:**
- Modify: `Sources/BetterCastShared/PairingSecretStore.swift`
- Modify: `Sources/BetterCastSender/BetterCastSenderApp.swift`
- Modify: `Sources/BetterCastReceiverIOS/ViewController.swift`

- [ ] **Step 1: Write failing tests for secret-store abstraction**

Use an in-memory store protocol for tests:

```swift
public protocol PairingSecretStoring {
    func loadSecret() throws -> Data?
    func saveSecret(_ secret: Data) throws
    func deleteSecret() throws
}
```

Run:

```bash
swift test --filter PairingSecretStoreTests
```

Expected: FAIL until the protocol/store implementation exists.

- [ ] **Step 2: Implement Keychain-backed store**

Implement `KeychainPairingSecretStore` using Security.framework:
- `kSecClassGenericPassword`
- service from `PrivateBetterCastConstants.appGroupKeychainService`
- account from `PrivateBetterCastConstants.pairingSecretAccount`

Do not log the secret.

- [ ] **Step 3: Add Mac pairing settings UI**

In `Sources/BetterCastSender/BetterCastSenderApp.swift`, add a Settings section:
- Secure pairing code field.
- Save button.
- Clear pairing button.
- Status label: paired/not paired.

The code should normalize to a secret with `PairingAuthenticator.normalizedSecret(from:)`.

- [ ] **Step 4: Add iPad pairing setup UI**

In `Sources/BetterCastReceiverIOS/ViewController.swift`:
- On first launch, show pairing-code field before starting the network listener.
- Save pairing code to Keychain.
- Start listener only after a secret exists.
- Add a settings overlay action to reset pairing.

- [ ] **Step 5: Verify no secret logging**

Run:

```bash
rg -n "pairing|secret|HMAC|token|code" Sources
```

Expected: no logs print the raw secret or pairing code.

- [ ] **Step 6: Build Mac sender**

Run:

```bash
swift build --target BetterCastSender
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/BetterCastShared Sources/BetterCastSender/BetterCastSenderApp.swift Sources/BetterCastReceiverIOS/ViewController.swift
git commit -m "feat: add private pairing setup"
```

---

## Task 3: Make iPad Receiver Apple-Only And TCP-Only

**Files:**
- Modify: `Sources/BetterCastReceiverIOS/Info.plist`
- Modify: `Sources/BetterCastReceiverIOS/Constants.swift`
- Modify: `Sources/BetterCastReceiverIOS/NetworkListenerIOS.swift`

- [ ] **Step 1: Update iOS bundle and Bonjour plist**

Change:
- `CFBundleIdentifier` to `com.yichen.privatebettercast.receiver.ios`
- `NSBonjourServices` from `_bettercast._tcp`/`_bettercast._udp` to `_yc-bettercast._tcp`

- [ ] **Step 2: Disable public Wi-Fi listener**

In `NetworkListenerIOS.start()`, call only the private P2P TCP listener path.

Remove active calls to:
- Public `startTCP()` Wi-Fi listener on port `51820`
- `startUDP()`

The implementation can keep helper methods temporarily if they are not called.

- [ ] **Step 3: Advertise private service type**

Change P2P listener service:

```swift
p2pListener.service = NWListener.Service(
    name: "\(deviceName) Private",
    type: PrivateBetterCastConstants.serviceType
)
```

- [ ] **Step 4: Add connection authentication state**

Add per-connection session state:
- unauthenticated
- authenticated with session key
- sequence counters for input envelopes

Do not call `receiveTCP` video handling until handshake succeeds.

- [ ] **Step 5: Build iOS target through Xcode or SwiftPM/Xcode integration**

Preferred:

```bash
xcodebuild -scheme BetterCastReceiverIOS -destination 'generic/platform=iOS' build
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/BetterCastReceiverIOS
git commit -m "feat: restrict ipad receiver to private p2p tcp"
```

---

## Task 4: Make Mac Sender Apple-Only And Sender-Only

**Files:**
- Modify: `BetterCastSender-Info.plist`
- Modify: `Sources/BetterCastSender/Constants.swift`
- Modify: `Sources/BetterCastSender/BetterCastSenderApp.swift`
- Modify: `Sources/BetterCastSender/LogManager.swift`

- [ ] **Step 1: Change Mac bundle ID**

In `BetterCastSender-Info.plist`, change:

```xml
<string>com.yichen.privatebettercast.sender</string>
```

This creates a separate Screen Recording/Accessibility permission identity from public BetterCast.

- [ ] **Step 2: Disable Mac receiver auto-start**

Remove or guard this startup path in `BetterCastSenderApp.mainView.onAppear`:

```swift
let receiver = ReceiverManager.shared
if !receiver.isRunning {
    receiver.start()
}
```

Expected result: launching the private Mac app opens no inbound receiver listener.

- [ ] **Step 3: Hide receiver UI**

Remove the sidebar `Receive Screen` row and related tour step from active UI.

Do not delete `ReceiverMode.swift` yet unless deletion is low-risk after compilation.

- [ ] **Step 4: Disable public update check**

Remove automatic call:

```swift
UpdateChecker.shared.checkForUpdates()
```

Remove or hide:
- update banner
- Report Issue button
- GitHub issue URL creation

- [ ] **Step 5: Force private defaults**

Set defaults:
- `useVirtualDisplay = true`
- `audioStreamingEnabled = false`
- `connectionType = "TCP"`
- `interfacePreference = .p2pOnly`
- `autoConnect = false`

The user can manually press Connect after seeing the paired iPad.

- [ ] **Step 6: Browse private service type only**

In `NetworkClient.startBrowsing()`, use:

```swift
let typeVal = PrivateBetterCastConstants.serviceType
```

Do not browse `_bettercast._tcp` or `_bettercast._udp` in the private app.

- [ ] **Step 7: Remove Android/Windows/Linux controls from active UI**

Hide:
- ADB USB/Wi-Fi buttons and status.
- Manual IP connect for non-Apple devices.
- Any copy that instructs installing Windows/Linux/Android receivers.

Keep the code only if removing it causes too large a patch.

- [ ] **Step 8: Build Mac sender**

Run:

```bash
swift build --target BetterCastSender
```

Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add BetterCastSender-Info.plist Sources/BetterCastSender
git commit -m "feat: make mac app private sender only"
```

---

## Task 5: Authenticate Mac-to-iPad Connection Before Starting Stream

**Files:**
- Modify: `Sources/BetterCastSender/BetterCastSenderApp.swift`
- Modify: `Sources/BetterCastReceiverIOS/NetworkListenerIOS.swift`

- [ ] **Step 1: Define handshake message structs**

Add Codable structs in `BetterCastShared` or the closest shared file:

```swift
public struct SenderHello: Codable {
    public let version: UInt8
    public let senderNonce: Data
}

public struct ReceiverHello: Codable {
    public let receiverNonce: Data
    public let receiverProof: Data
}

public struct SenderProof: Codable {
    public let senderProof: Data
}
```

- [ ] **Step 2: Add Mac sender handshake before pipeline creation**

Current code creates pipeline immediately in `NWConnection.State.ready`. Change flow:
1. TCP connection becomes ready.
2. Load pairing secret.
3. Send `SenderHello`.
4. Receive `ReceiverHello`.
5. Verify receiver proof.
6. Send `SenderProof`.
7. Derive session key.
8. Mark pipeline authenticated.
9. Start `startPipeline(for:)`.

- [ ] **Step 3: Add iPad receiver handshake before video decode**

Current code calls `receiveTCP(on:)` as soon as the connection is ready. Change flow:
1. TCP connection becomes ready.
2. Load pairing secret.
3. Receive `SenderHello`.
4. Send `ReceiverHello`.
5. Receive and verify `SenderProof`.
6. Store session key.
7. Start video receive loop.

- [ ] **Step 4: Add failure behavior**

If handshake fails:
- Log only generic failure, not secrets.
- Cancel connection.
- Do not start video decoding.
- Do not send input events.
- Show "Pairing failed" on iPad status label.

- [ ] **Step 5: Add targeted tests for handshake helper methods**

Run:

```bash
swift test --filter PairingAuthenticatorTests
```

Expected: PASS.

- [ ] **Step 6: Build both targets**

Run:

```bash
swift build --target BetterCastSender
xcodebuild -scheme BetterCastReceiverIOS -destination 'generic/platform=iOS' build
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/BetterCastShared Sources/BetterCastSender/BetterCastSenderApp.swift Sources/BetterCastReceiverIOS/NetworkListenerIOS.swift
git commit -m "feat: require pairing before stream startup"
```

---

## Task 6: Authenticate iPad Input Events

**Files:**
- Modify: `Sources/BetterCastReceiverIOS/NetworkListenerIOS.swift`
- Modify: `Sources/BetterCastSender/BetterCastSenderApp.swift`
- Modify: `Sources/BetterCastSender/InputHandler.swift`
- Modify: `Sources/BetterCastReceiverIOS/VideoRendererViewIOS.swift`

- [ ] **Step 1: Wrap input events in authenticated envelopes**

In iPad `sendInputEvent(_:)`:
- JSON-encode `InputEvent`.
- Wrap it in `AuthenticatedEnvelope`.
- Increment send sequence.
- Send length-prefixed envelope.

- [ ] **Step 2: Verify input envelopes on Mac**

In Mac receive path:
- Decode envelope first.
- Verify MAC with session key.
- Reject duplicate or regressed sequence values.
- Decode payload into `InputEvent`.
- Only then call command handling or `InputHandler.shared.handle`.

- [ ] **Step 3: Keep command events authenticated**

Authenticated command events include:
- `777` screen info
- `888` heartbeat
- `999` keyframe request

No unauthenticated command should affect pipeline state.

- [ ] **Step 4: Add an explicit guard in `InputHandler`**

Keep `InputHandler` dumb about networking, but add a method boundary or call-site guarantee so the only path into `handle(event:for:)` is post-authentication. Prefer call-site guard in `NetworkClient` to avoid coupling input injection to auth internals.

- [ ] **Step 5: Add pointer/keyboard verification**

Inspect whether UIKit pointer/keyboard events are fully captured. If iPad-connected keyboard input is not currently captured, add `UIKeyCommand`/presses handling in `ViewController` or `VideoRendererViewIOS`.

Minimum expected input:
- tap = click
- drag = move/drag
- two-finger pan = scroll
- external keyboard letters and modifiers generate keyDown/keyUp when possible

- [ ] **Step 6: Run tests**

Run:

```bash
swift test --filter PairingAuthenticatorTests
```

Expected: PASS.

- [ ] **Step 7: Build**

Run:

```bash
swift build --target BetterCastSender
xcodebuild -scheme BetterCastReceiverIOS -destination 'generic/platform=iOS' build
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add Sources/BetterCastShared Sources/BetterCastSender Sources/BetterCastReceiverIOS
git commit -m "feat: authenticate ipad input events"
```

---

## Task 7: Update Private Build And Usage Documentation

**Files:**
- Modify: `README.md`
- Modify: `make_app.sh`
- Optionally create: `docs/private-mac-ipad.md`

- [ ] **Step 1: Document private scope**

State clearly:
- This fork is for one Mac and one iPad.
- It is not a public cross-platform build.
- It requires Screen Recording and Accessibility on Mac.
- It does not support Windows/Linux/Android in the private first version.

- [ ] **Step 2: Document build commands**

Mac:

```bash
swift build -c release --target BetterCastSender
SIGN_IDENTITY="-" ./make_app.sh
```

iPad:

```bash
xcodebuild -scheme BetterCastReceiverIOS -destination 'generic/platform=iOS' build
```

Then install through Xcode to the iPad.

- [ ] **Step 3: Update `make_app.sh` for private local signing**

Default `SIGN_IDENTITY` to `-` for local ad-hoc builds unless the user sets a Developer ID explicitly.

- [ ] **Step 4: Document pairing and use**

Usage flow:
1. Install Mac app.
2. Grant Screen Recording and Accessibility.
3. Install iPad app.
4. Enter the same pairing code on both devices.
5. Open iPad app.
6. On Mac, connect to the private iPad receiver.
7. Arrange displays in macOS Settings.

- [ ] **Step 5: Commit**

```bash
git add README.md make_app.sh docs/private-mac-ipad.md
git commit -m "docs: document private mac ipad workflow"
```

---

## Task 8: Final Cleanup And Security Pass

**Files:**
- Review all changed files.

- [ ] **Step 1: Search for active public service types**

Run:

```bash
rg -n "_bettercast|51820|51821|startUDP|ReceiverManager.shared|UpdateChecker.shared.checkForUpdates|Report Issue|bettercast.online|ADB|Windows|Linux|Android" Sources BetterCastSender-Info.plist Sources/BetterCastReceiverIOS/Info.plist README.md
```

Expected:
- `_bettercast`, UDP, ADB, Windows, Linux, Android may remain only in inactive legacy source or historical docs.
- No active private Mac/iPad app startup path uses them.
- No automatic update/report URL remains active.

- [ ] **Step 2: Search for secret leakage**

Run:

```bash
rg -n "print\\(|LogManager.*secret|LogManager.*pairing|pairing code|HMAC|sessionKey" Sources
```

Expected:
- No raw pairing code, secret, or session key is logged.

- [ ] **Step 3: Run tests**

Run:

```bash
swift test
```

Expected: PASS.

- [ ] **Step 4: Build release Mac app**

Run:

```bash
swift build -c release --target BetterCastSender
```

Expected: PASS.

- [ ] **Step 5: Build iOS app**

Run:

```bash
xcodebuild -scheme BetterCastReceiverIOS -destination 'generic/platform=iOS' build
```

Expected: PASS.

- [ ] **Step 6: Verify signing identity of local Mac app**

After packaging:

```bash
codesign --verify --deep --strict BetterCast.app
codesign -dv --verbose=4 BetterCast.app
spctl --assess --type execute --verbose BetterCast.app
```

Expected:
- `codesign --verify` passes.
- If ad-hoc signed, `spctl` may reject distribution, which is acceptable for local-only builds. Do not distribute ad-hoc builds.

- [ ] **Step 7: Commit**

```bash
git add .
git commit -m "chore: verify private mac ipad build"
```

---

## Manual Acceptance Criteria

### Security Acceptance

- [ ] Mac app does not auto-start receiver mode.
- [ ] Mac app does not listen as a receiver on TCP `51820`.
- [ ] iPad app does not advertise `_bettercast._tcp` or `_bettercast._udp`.
- [ ] iPad app advertises only the private service type `_yc-bettercast._tcp`.
- [ ] Mac app browses only `_yc-bettercast._tcp`.
- [ ] Wrong pairing code prevents connection.
- [ ] Wrong pairing code prevents video from starting.
- [ ] Wrong pairing code prevents input from affecting the Mac.
- [ ] Pairing code/session key never appears in logs.
- [ ] No automatic GitHub release check happens on Mac app launch.
- [ ] No Report Issue flow opens GitHub with logs.

### Functional Acceptance

- [ ] With matching pairing codes, Mac discovers the iPad.
- [ ] Clicking Connect creates a virtual display on the Mac.
- [ ] macOS Displays settings shows the BetterCast virtual display.
- [ ] The iPad shows the virtual display image within 5 seconds after connection.
- [ ] Text is readable at the selected default resolution.
- [ ] Moving Mac's own pointer into the virtual display works.
- [ ] Tapping on iPad performs a click on the virtual display.
- [ ] Dragging on iPad moves/drag-selects on the virtual display.
- [ ] Two-finger pan on iPad scrolls content on the virtual display.
- [ ] iPad-connected keyboard input works for normal text entry where UIKit can capture it.
- [ ] Disconnect tears down the virtual display.
- [ ] Reconnect works without restarting both apps.

### Stability Acceptance

- [ ] 30-minute connected session does not crash on Mac.
- [ ] 30-minute connected session does not crash on iPad.
- [ ] Sleep/wake or iPad app background/foreground either reconnects cleanly or fails with a clear status.
- [ ] If iPad disconnects, Mac removes the virtual display within 15 seconds.
- [ ] CPU and memory remain reasonable during a 1080p or iPad-native stream.

### Permission Acceptance

- [ ] Mac app requests Screen Recording only for screen capture.
- [ ] Mac app requests Accessibility only for iPad-originated input.
- [ ] iPad app requests Local Network permission.
- [ ] iPad app does not request camera, microphone, photos, contacts, or location.

---

## Recommended Implementation Order

1. Task 1: Shared pairing/auth tests and implementation.
2. Task 2: Pairing secret setup UI/storage.
3. Task 3: iPad private P2P TCP receiver.
4. Task 4: Mac private sender-only app.
5. Task 5: Authenticated connection handshake.
6. Task 6: Authenticated input events.
7. Task 7: Private docs/build scripts.
8. Task 8: Final cleanup/security pass.

This order keeps the riskiest security boundary testable before UI and networking are fully rewired.
