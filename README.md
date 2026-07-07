# iphone2win

iphone2win is a privacy-hardened LocalSend fork for LAN-only file transfer between Apple devices and Windows devices.

This fork removes LocalSend public signaling/STUN defaults and store donation purchases. See [docs/privacy.md](docs/privacy.md) for the enforced privacy boundary.

## Privacy Scope

iphone2win keeps local-network discovery and direct device-to-device transfer. It does not use public discovery, signaling, STUN, TURN, telemetry, analytics, crash reporting, ads, in-app purchase, or donation SDKs.

The app must not advertise alias, version, device model, device type, token, fingerprint, or public IP address to a third-party service during startup, discovery, sending, or receiving.

Run the static guard before release:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\privacy_audit.ps1
```

## Transfer Model

- Devices must be on the same local network.
- Discovery uses local-network multicast.
- File bytes move directly between sender and receiver over local HTTP or HTTPS.
- No third-party server participates in discovery, negotiation, or transfer.

## Build Notes

The app code lives in `app/`.

```powershell
cd app
flutter pub get
dart run build_runner build -d
flutter analyze
flutter test
flutter build windows --debug
```

iOS builds require macOS and Xcode.

## Upstream

iphone2win is based on [LocalSend](https://github.com/localsend/localsend). LocalSend is licensed under Apache-2.0; see [LICENSE](LICENSE).
