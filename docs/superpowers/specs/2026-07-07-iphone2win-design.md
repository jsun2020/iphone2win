# iphone2win Privacy-Hardened Fork Design

## Context

iphone2win is a privacy-hardened fork of LocalSend focused on bidirectional file transfer between Apple devices and Windows devices. The upstream project already provides the core local-network transfer flow, but the current default app also contains a public WebRTC signaling path and an in-app-purchase donation dependency. This fork removes those surfaces and keeps the product small, auditable, and local-first.

The starting upstream commit is `5ccc6dea192d1c697c2602bf456b2eb2ad8e9674`.

## Goals

- Support bidirectional file transfer between iPhone or iPad and Windows on the same local network.
- Keep local discovery and transfer behavior, including UDP multicast discovery and direct HTTP or HTTPS transfer on the local network.
- Remove all default public discovery, signaling, STUN, TURN, telemetry, analytics, crash reporting, ad, and in-app-purchase surfaces.
- Prevent the app from sending alias, version, device model, device type, token, fingerprint-like identifiers, or public IP information to LocalSend-operated public services.
- Replace donation and proprietary-store purchase code with a pure FOSS build.
- Rename the user-facing product and package metadata to iphone2win where this is practical without broad unrelated rewrites.
- Add automated privacy checks that fail when removed public-service or proprietary dependency surfaces reappear.

## Non-Goals

- No internet relay mode.
- No NAT traversal through public signaling, STUN, TURN, or relay infrastructure.
- No account system.
- No cloud sync.
- No analytics dashboard or crash reporting service.
- No new transfer protocol. The fork reuses the existing local transfer protocol unless a removal requires a narrowly scoped adapter.
- No support expansion beyond the upstream-supported Apple and Windows targets in this first pass.

## Privacy Boundary

The enforceable privacy boundary is: the app must not initiate network connections to public discovery, signaling, STUN, TURN, telemetry, analytics, crash reporting, ads, donation, or purchase services during normal discovery, sending, receiving, or startup.

Allowed network behavior:

- Local UDP multicast discovery on the existing LocalSend discovery group and port.
- Direct local HTTP or HTTPS transfer between the sender and receiver.
- Local loopback or platform runtime traffic needed by Flutter tooling during development.

Disallowed network behavior:

- WebSocket signaling to the LocalSend public signaling host.
- STUN lookup against the LocalSend public STUN host.
- Any default TURN, relay, telemetry, analytics, crash reporting, ad, purchase, or donation service.
- Any app startup task that advertises this device to a third-party service.

This design does not claim mathematically absolute absence of risk. It makes the risk boundary testable: no known public-service egress or hidden collection path remains in app code, generated bridge code, package dependencies, or platform plugin registrants.

## Architecture

The fork keeps the local-network transfer architecture and removes the internet-assist architecture.

Kept components:

- Local device discovery.
- Direct send and receive flows.
- Encryption and pairing behavior already used by local transfer.
- iOS and Windows platform support.
- Existing app settings that are local-only and do not require a remote service.

Removed or disabled components:

- App startup dispatch of the signaling connection setup action.
- The signaling provider defaults that point to public signaling and STUN services.
- UI entry points and settings for public signaling or internet discovery.
- WebRTC send and receive providers if they are only reachable through public signaling.
- Rust WebRTC API bridge exports and generated bindings when the Dart app no longer uses them.
- Server code or metadata that exists only for LocalSend public signaling if it is included in the fork's active build paths.
- In-app purchase provider, donation purchase view model paths, and generated StoreKit plugin registrants.

## Data Flow

Local discovery:

1. Device A sends a local-network multicast announcement.
2. Device B receives the announcement and displays Device A as a nearby peer.
3. The announcement may contain local-only peer metadata needed for discovery, but this metadata must stay on the LAN.

Local transfer:

1. Sender selects files and chooses a discovered peer.
2. Sender sends the transfer request directly to the receiver's local address.
3. Receiver accepts or declines.
4. File bytes move directly between the two devices over the local network.
5. No third-party server participates in discovery, negotiation, or byte transfer.

Startup:

1. App initializes local settings, local network server, local discovery, and app UI.
2. App does not connect to any public signaling, STUN, telemetry, analytics, crash reporting, purchase, or donation service.

## Code Areas

Primary app files expected to change:

- `app/pubspec.yaml`: remove `in_app_purchase` and any non-FOSS dependency that is only used for donation or purchase behavior.
- `app/pubspec.lock`: regenerate after dependency removal.
- `app/lib/config/init.dart`: remove purchase initialization and remove startup signaling dispatch.
- `app/lib/provider/purchase_provider.dart`: delete or replace with a local no-op abstraction only if imports require it temporarily.
- `app/lib/pages/donation/donation_page.dart`: remove purchase behavior and convert the route to a simple FOSS information page or remove the route.
- `app/lib/pages/donation/donation_page_vm.dart`: remove purchase behavior.
- `app/lib/provider/network/webrtc/signaling_provider.dart`: remove active public signaling behavior or delete if all callers are removed.
- `app/lib/provider/network/webrtc/webrtc_receiver.dart`: remove if no longer used.
- `app/lib/rust/api/webrtc.dart` and generated `frb_generated` bridge files: remove or regenerate when Dart no longer imports WebRTC APIs.
- `app/rust/src/api/webrtc.rs` and `app/rust/src/api/mod.rs`: remove WebRTC bridge module from the app crate if no longer referenced.
- `app/ios/Podfile.lock`, `app/macos/Podfile.lock`, and generated plugin registrants: regenerate to remove StoreKit purchase plugin references.

Supporting files expected to change:

- `README.md`: describe iphone2win as LAN-only and privacy-hardened.
- `app/README.md` or a new privacy document: document allowed and disallowed network behavior.
- `scripts/privacy_audit.ps1`: Windows-friendly privacy scan for banned hosts, dependency names, and telemetry packages in active app paths.
- `scripts/privacy_audit.sh`: optional shell equivalent for non-Windows environments.

## Implementation Strategy

1. Add failing privacy audit checks first.
2. Remove in-app purchase dependency and all purchase imports.
3. Remove purchase initialization and donation purchase UI behavior.
4. Remove public signaling startup behavior.
5. Remove or isolate WebRTC signaling code so public signaling and STUN defaults cannot be reached.
6. Regenerate Flutter dependencies and platform plugin registrants.
7. Run dependency, static grep, and platform build checks for iOS-relevant and Windows-relevant targets where the local environment supports them.
8. Update documentation after behavior is verified.

## Testing

Required automated checks:

- A privacy audit script scans active source, dependency, and platform files for banned public-service hosts, purchase dependencies, and common telemetry SDKs.
- Flutter dependency resolution succeeds after dependency removal.
- Flutter analysis passes for the app.
- Existing local transfer tests continue to pass where they are available.
- A targeted test verifies startup no longer dispatches signaling connection setup.
- A targeted test verifies purchase provider imports are gone from active app code.

Manual verification:

- Launch on Windows.
- Launch on iPhone or iOS simulator when available.
- Confirm Windows can discover Apple device on the same LAN.
- Confirm Apple device can discover Windows on the same LAN.
- Send a file from Windows to Apple device.
- Send a file from Apple device to Windows.
- Observe that no connection is attempted to LocalSend public signaling or STUN services during startup, discovery, or transfer.

## Acceptance Criteria

- `app/pubspec.yaml` does not include `in_app_purchase`.
- Generated iOS and macOS plugin registrants do not include StoreKit purchase plugins.
- App startup does not dispatch signaling setup.
- Active app code contains no default public signaling host or public STUN host.
- Active app code contains no analytics, ads, telemetry, crash reporting, or purchase SDK dependency.
- Privacy audit script exits non-zero when a banned host, banned dependency, or banned SDK appears in active app paths.
- Local iPhone or iPad to Windows transfer remains functional on the same LAN.
- Windows to local iPhone or iPad transfer remains functional on the same LAN.
- Documentation states that iphone2win is LAN-only and does not provide internet relay.

## Risks And Mitigations

- Removing WebRTC may break internet-assisted transfer flows. This is accepted because internet relay and NAT traversal are out of scope.
- Generated Flutter and Rust bridge files may need regeneration. The implementation plan must use the repo's existing generation commands instead of hand-editing large generated files where practical.
- Local network permission behavior on iOS is sensitive to platform configuration. Keep iOS local-network entitlement and usage descriptions intact while removing only internet-assist and purchase surfaces.
- Some upstream naming may remain internally to avoid a broad risky rename. User-facing names and privacy-critical paths take priority over full internal namespace renaming.

## Review Decision

Proceed with a privacy-hardened LocalSend fork named iphone2win, scoped to LAN-only Apple-device and Windows-device file transfer, with public signaling, STUN, purchase, donation, and telemetry-style surfaces removed or blocked by tests.
