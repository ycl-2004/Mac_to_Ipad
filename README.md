# YC Cast

YC Cast turns an iPad into an extended display for a Mac. The Mac creates a virtual display, streams it to the iPad over the local network, and can accept authenticated touch, pointer, scroll, and keyboard input from the paired iPad.

The current product path is Mac sender plus iPad receiver.

## Features

- Mac virtual display streaming to iPad over TCP.
- Default display placement on the right side of the Mac display, with a setting for right, left, above, or below.
- HiDPI resolution presets, including a larger-text `1024 x 768` option for easier reading on iPad.
- Pairing-code based authentication before streaming starts.
- Authenticated iPad input events before macOS Accessibility injection.
- Device de-duplication, hidden device records, and manual device removal.
- iPad disconnected screen when the Mac stops sharing or the network drops.

## Security Model

- Pairing codes are normalized, hashed, and stored locally in Keychain on both Mac and iPad.
- Mac and iPad perform a nonce-based HMAC-SHA256 handshake before streaming starts.
- A session key derived from the pairing secret and both nonces authenticates iPad input events.
- The Mac rejects unauthenticated, tampered, or replayed input before calling the CGEvent injection path.
- Bonjour discovery uses the YC Cast service type `_yc-cast._tcp`.

YC Cast still needs sensitive macOS permissions. Screen Recording is required to capture the virtual display, and Accessibility is required only if iPad input should control the Mac.

## Quick Start

Use a long pairing code that is not reused anywhere else. Save the exact same code on both devices.

### Mac

1. Build the app with `./make_app.sh`, or open a release zip/DMG.
2. Move `YC Cast.app` to `/Applications`.
3. Open YC Cast and save the pairing code in Settings.
4. Keep `Use as` set to `Extended Display`.
5. Grant Screen Recording when prompted.
6. Grant Accessibility if you want touch, mouse, and keyboard input from the iPad.

### iPad

1. Open `BetterCastIOS.xcodeproj` in Xcode.
2. Select the `BetterCastReceiverIOS` scheme and your iPad as the run destination.
3. Let Xcode automatically manage signing with your Apple Personal Team, then click Run.
4. If Xcode asks, trust the iPad and enable Developer Mode on iPadOS versions that require it.
5. Enter and save the same pairing code used on the Mac.
6. Leave the receiver open.
7. When the iPad appears in the Mac sidebar, connect from the Mac.

## Build Commands

Run the shared authentication tests:

```bash
swift test --filter BetterCastSharedTests
```

Build the Mac app and DMG locally:

```bash
env SIGN_IDENTITY=- ./make_app.sh
```

Build the iPad receiver for a real device:

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

## Distribution Notes

`make_app.sh` defaults to ad-hoc signing when `SIGN_IDENTITY=-`, which is useful for local testing and sharing with trusted friends. For a smoother public download experience, sign with your own Developer ID certificate and notarize the DMG:

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
APPLE_ID="you@example.com" \
APP_PASSWORD="app-specific-password" \
TEAM_ID="TEAMID" \
./make_app.sh
```

Generated apps, DMGs, zips, and local sharing folders are ignored by Git and should be uploaded as GitHub release assets instead of committed to the repository.

## Manual Acceptance Checklist

- With no pairing code saved on the Mac, connecting to an iPad does not start screen capture.
- With different pairing codes on Mac and iPad, the connection fails during pairing.
- With the same pairing code, the Mac connects and starts streaming only after authentication succeeds.
- The iPad shows the streamed virtual display.
- Touch or pointer input on the iPad moves/clicks only inside the paired Mac display.
- Keyboard input from the iPad affects the paired Mac display when Accessibility is granted.
- Clearing pairing on either device prevents future connections until the code is saved again.
- Stop Sharing on the Mac returns the iPad to the disconnected screen.

## Architecture Notes

The shared security code lives in `Sources/BetterCastShared`:

- `PrivateBetterCastConstants.swift` holds the YC Cast service type and protocol constants.
- `PairingAuthenticator.swift` implements nonce generation, HMAC proofs, session key derivation, and authenticated envelopes.
- `PairingSecretStore.swift` stores the local pairing secret through Keychain.

The main runtime gates are:

- Mac: `NetworkClient.performPairingHandshake(...)` must succeed before `startPipeline(for:)`.
- iPad: `NetworkListenerIOS.performPairingHandshake(...)` must succeed before a connection is added to `connectedClients`.
- Mac input: `NetworkClient.receiveTCP(...)` verifies `AuthenticatedEnvelope` before dispatching to `InputHandler`.
- iPad input: `NetworkListenerIOS.sendInputEvent(...)` seals each input event with the session key.

Some internal Swift package targets and source paths still use historical `BetterCast*` names. The user-facing app name, bundle display name, service type, packaging scripts, and release documentation are YC Cast.

See `docs/decisions/ADR-001-private-mac-ipad-authenticated-p2p.md` for the design rationale.
