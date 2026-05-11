# ADR-001: Private Mac-iPad Authenticated P2P Build

## Status

Accepted

## Date

2026-05-11

## Context

The goal is to use BetterCast as a private Sidecar-like workflow: a Mac creates an extended display, streams it to an iPad, and accepts iPad-originated touch, pointer, and keyboard input.

The upstream app is broader than this goal. It includes cross-platform receivers, Mac receiver mode, Android ADB support, UDP transport, update checks, and GitHub issue-report flows. Those surfaces are not needed for a private Mac+iPad setup and increase review and trust burden.

The most sensitive permissions are Screen Recording and Accessibility. Screen Recording is needed to capture the display. Accessibility is needed for CGEvent input injection. Because those permissions cannot be removed while preserving the requested functionality, the private build needs a stricter local authentication gate before streaming or accepting input.

## Decision

Build a private Apple-only path with:

- A shared `BetterCastShared` module for pairing and authentication.
- A private Bonjour service type: `_yc-bettercast._tcp`.
- Keychain-backed pairing secret storage on Mac and iPad.
- A nonce-based HMAC-SHA256 handshake before the Mac starts the streaming pipeline.
- TCP-only transport for the private first version.
- Authenticated input envelopes from iPad to Mac using a derived session key and monotonic sequence.
- Mac sender-only primary UI.
- No public automatic update check or external issue-report upload path.

## Alternatives Considered

### Trust Any Local Receiver

This matches the simpler upstream behavior, but it is not appropriate when the Mac grants Accessibility. Any device able to connect on the local network could attempt to send input messages.

Rejected because the requested workflow needs remote control of the Mac.

### TLS With Certificates

TLS could protect stream confidentiality and authentication, but certificate generation, trust pinning, renewal, and iOS/macOS storage would make the first private build much more complex.

Deferred. The current private threat model is trusted local devices plus HMAC authentication against spoofed local input/control messages.

### Keep UDP For Lower Latency

UDP can reduce latency, but the existing UDP path was unauthenticated and chunk-based. Authenticating every UDP packet or building a replay-safe UDP envelope would be more work than the first private version needs.

Rejected for now. TCP is simpler, ordered, and enough for the initial private Mac+iPad workflow.

### Remove Accessibility

Removing Accessibility would avoid input injection risk, but it would also remove the user's required ability to control the Mac display from the iPad.

Rejected because iPad mouse, keyboard, and touch control are in scope.

## Consequences

- The Mac will not start screen capture until pairing succeeds.
- The iPad will not send input on unauthenticated connections.
- The Mac will reject tampered or replayed input envelopes.
- The app still requires careful local trust because video/audio frames are not encrypted.
- Public cross-platform code remains in the repository but is inactive in the private product path.
- Future cleanup can delete dormant Windows, Linux, Android, Mac receiver, and UDP code once the private path has been manually verified on real devices.
