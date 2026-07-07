# iphone2win Privacy Boundary

iphone2win is a LAN-only file transfer app for Apple devices and Windows devices.

Allowed network behavior:

- UDP multicast discovery on the local network.
- Direct HTTP or HTTPS transfer between devices on the same local network.
- Local browser upload from an Apple device to Windows by scanning a QR code shown by the Windows app. The QR code contains only the local URL path `http://<local-ip>:<port>/upload`.
- Local loopback traffic used by the operating system or development tooling.

Disallowed network behavior:

- No LocalSend public signaling server.
- No LocalSend public STUN server.
- No TURN or relay server.
- No telemetry, analytics, crash reporting, ads, in-app purchase, or donation SDK.
- No startup task that advertises alias, version, device model, device type, token, fingerprint, or public IP address to a third-party service.

iphone2win does not provide internet relay. Devices must be reachable on the same local network.

QR browser upload privacy boundary:

- The Windows app serves `/upload` and `/upload.js` from bundled local assets.
- The upload page uses only relative same-origin API calls to `/api/localsend/v2/prepare-upload` and `/api/localsend/v2/upload`.
- The QR code does not include alias, app version, device model, device type, token, fingerprint, or public IP address.
- No remote script, stylesheet, image, analytics endpoint, signaling service, STUN server, TURN server, relay, or third-party server is referenced by the upload page.
- The QR upload URL uses HTTP on the local network for iPhone browser compatibility with self-signed certificates. Use a trusted LAN, keep Quick Save off when manual approval is preferred, and enable a receive PIN when appropriate.
