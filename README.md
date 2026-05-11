# Private BetterCast for Mac and iPad

This fork is a private Mac-to-iPad screen extension build. The intended use is:

1. The Mac creates an extended virtual display.
2. The Mac streams that display to a paired iPad.
3. The iPad sends touch, pointer, scroll, and keyboard input back to the Mac.
4. The Mac accepts that input only after the iPad proves it knows the same pairing code.

This is no longer the public cross-platform BetterCast product path. Windows, Linux, Android, Mac receiver mode, public auto-update, and public issue-report upload flows are intentionally inactive for this private build.

## Current Safety Model

- Pairing code is normalized, hashed, and stored locally in Keychain on both Mac and iPad.
- The Mac and iPad perform a nonce-based HMAC-SHA256 handshake before streaming starts.
- A session key derived from the pairing secret and both nonces authenticates iPad input events.
- iPad input is wrapped in an authenticated envelope with a sequence number and HMAC.
- The Mac rejects unauthenticated, tampered, or replayed input before calling the CGEvent injection path.
- Bonjour discovery uses the private service type `_yc-bettercast._tcp`.
- iPad receiver startup uses Apple peer-to-peer networking first and TCP only.
- The Mac app does not auto-start the Mac receiver, check GitHub releases, or open a prefilled GitHub issue with logs.

This does not make the app magic-safe. The Mac still needs Screen Recording to capture the display and Accessibility to inject mouse and keyboard events. Use it only with your own builds and your own devices.

## Quick Start

Use a long pairing code that is not reused anywhere else. Save the exact same code on both devices.

### Mac

1. Build and run the `BetterCastSender` target from this source tree.
2. Open Settings in the app.
3. Save the pairing code.
4. Keep `Use as` set to `Extended Display`.
5. Grant Screen Recording when prompted.
6. Grant Accessibility only if you want iPad input to control the Mac.

### iPad

1. Open `BetterCastIOS.xcodeproj` in Xcode.
2. Select the `BetterCastReceiverIOS` scheme and your iPad as the run destination.
3. Let Xcode automatically manage signing with your Apple Personal Team, then click Run.
4. If Xcode asks, pair/trust the iPad and enable Developer Mode on iPadOS versions that require it.
5. Enter and save the same pairing code used on the Mac.
6. Leave the receiver open.
7. When the iPad appears in the Mac sidebar, connect from the Mac.

## Commands

Run the shared authentication tests:

```bash
swift test --filter BetterCastSharedTests
```

Build the Mac sender:

```bash
swift build --target BetterCastSender
```

Build the iPad receiver for device:

```bash
xcodebuild -project BetterCastIOS.xcodeproj \
  -scheme BetterCastReceiverIOS \
  -destination 'generic/platform=iOS' \
  -configuration Debug \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration \
  build
```

For a local iPad install, open `BetterCastIOS.xcodeproj`, choose the real iPad as the run destination, and use Product > Run.

## Manual Acceptance Checklist

Before trusting a local build, verify this behavior:

- With no pairing code saved on the Mac, connecting to an iPad does not start screen capture.
- With different pairing codes on Mac and iPad, the connection fails during pairing.
- With the same pairing code, the Mac connects and starts streaming only after authentication succeeds.
- The iPad shows the streamed virtual display.
- Touch or pointer input on the iPad moves/clicks only inside the paired Mac display.
- Keyboard input from the iPad affects the paired Mac display when Accessibility is granted.
- Clearing pairing on either device prevents future connections until the code is saved again.
- The Mac app does not show public Windows, Linux, Android, receiver mode, auto-update, or Report Issue flows in the primary UI.

## Known Limits

- This is a local private build, not a notarized public distribution.
- The stream is still local-network TCP without TLS. Pairing and input authentication reduce spoofing risk but are not a replacement for using a trusted network.
- Video and audio stream frames are authenticated by the initial paired session gate, not per-frame encrypted.
- CoreGraphics virtual display APIs are private and can break on future macOS versions.
- Dormant upstream cross-platform source files remain in the repository for now, but the private Mac+iPad path does not expose them in the main UI.

## Architecture Notes

The shared security code lives in `Sources/BetterCastShared`:

- `PrivateBetterCastConstants.swift` holds the private service type and protocol constants.
- `PairingAuthenticator.swift` implements nonce generation, HMAC proofs, session key derivation, and authenticated envelopes.
- `PairingSecretStore.swift` stores the local pairing secret through Keychain.

The main runtime gates are:

- Mac: `NetworkClient.performPairingHandshake(...)` must succeed before `startPipeline(for:)`.
- iPad: `NetworkListenerIOS.performPairingHandshake(...)` must succeed before a connection is added to `connectedClients`.
- Mac input: `NetworkClient.receiveTCP(...)` verifies `AuthenticatedEnvelope` before dispatching to `InputHandler`.
- iPad input: `NetworkListenerIOS.sendInputEvent(...)` seals each input event with the session key.

See `docs/decisions/ADR-001-private-mac-ipad-authenticated-p2p.md` for the design rationale.
