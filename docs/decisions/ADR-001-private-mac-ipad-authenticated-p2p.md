# ADR-001: YC Cast Mac-iPad Authenticated Local Streaming

## Status

Accepted

## Date

2026-05-11

## Context

YC Cast is designed as a local Mac-to-iPad workflow: a Mac creates an extended display, streams it to an iPad, and accepts iPad-originated touch, pointer, and keyboard input.

The sensitive permissions are Screen Recording and Accessibility. Screen Recording is needed to capture the display. Accessibility is needed for CGEvent input injection. Because those permissions cannot be removed while preserving the requested workflow, the app needs a strict local authentication gate before streaming or accepting input.

## Decision

Build the main product path with:

- A shared security module for pairing and authentication.
- Bonjour service type `_yc-cast._tcp`.
- Keychain-backed pairing secret storage on Mac and iPad.
- A nonce-based HMAC-SHA256 handshake before the Mac starts the streaming pipeline.
- TCP-only transport for the first Mac+iPad product path.
- Authenticated input envelopes from iPad to Mac using a derived session key and monotonic sequence.
- Mac sender primary UI.
- No automatic update check or external issue-report upload path in the app.

## Alternatives Considered

### Trust Any Local Receiver

This is simpler, but it is not appropriate when the Mac grants Accessibility. Any device able to connect on the local network could attempt to send input messages.

Rejected because YC Cast includes remote control of the Mac display from the iPad.

### TLS With Certificates

TLS could protect stream confidentiality and authentication, but certificate generation, trust pinning, renewal, and iOS/macOS storage would make the first local product path much more complex.

Deferred. The current threat model is trusted local networks plus HMAC authentication against spoofed local input/control messages.

### UDP For Lower Latency

UDP can reduce latency, but replay-safe authenticated UDP framing adds complexity that is not needed for the first product path.

Deferred. TCP is simpler, ordered, and enough for the current Mac+iPad workflow.

### Remove Accessibility

Removing Accessibility would avoid input injection risk, but it would also remove the required ability to control the Mac display from the iPad.

Rejected because iPad mouse, keyboard, and touch control are in scope.

## Consequences

- The Mac will not start screen capture until pairing succeeds.
- The iPad will not send input on unauthenticated connections.
- The Mac will reject tampered or replayed input envelopes.
- The app still requires local trust because video/audio frames are not encrypted.
- Future cleanup should either remove dormant non-Mac/iPad modules or fully rename and document them before a public GitHub release.
