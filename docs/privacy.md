# iphone2win Privacy Boundary

iphone2win is a LAN-only file transfer app for Apple devices and Windows devices.

Allowed network behavior:

- UDP multicast discovery on the local network.
- Direct HTTP or HTTPS transfer between devices on the same local network.
- Local loopback traffic used by the operating system or development tooling.

Disallowed network behavior:

- No LocalSend public signaling server.
- No LocalSend public STUN server.
- No TURN or relay server.
- No telemetry, analytics, crash reporting, ads, in-app purchase, or donation SDK.
- No startup task that advertises alias, version, device model, device type, token, fingerprint, or public IP address to a third-party service.

iphone2win does not provide internet relay. Devices must be reachable on the same local network.
