# iphone2win QR Upload Design

## Goal

Add a "scan to upload" flow so an iPhone can send files to the Windows receiver by scanning a QR code shown on the computer.

## User Experience

On the Windows `Receive` tab, add a small QR-code action near the existing top-right controls. When the server is running and at least one LAN IP is available, the action opens a QR dialog with a local upload URL such as:

```text
http://192.168.1.7:53317/upload
```

The iPhone user scans the QR code with Camera or a browser, selects one or more files, and uploads them. The Windows app keeps using the existing receiver flow: it prompts for accept/decline unless Quick Save is enabled, shows progress on the existing progress page, saves to the configured destination, and writes receive history.

If there are multiple local IP addresses, the dialog shows the first LAN address selected by the existing `localIpProvider`. The advanced info panel still shows all addresses for manual fallback.

## Architecture

The feature reuses the existing LocalSend v2 upload protocol instead of adding a parallel file-save path. A lightweight browser upload page is served by the existing local HTTP server at `/upload`. Browser JavaScript calls the existing receiver endpoints:

- `POST /api/localsend/v2/prepare-upload`
- `POST /api/localsend/v2/upload?sessionId=...&fileId=...&token=...`

This keeps file validation, accept/decline, Quick Save, progress state, destination directory handling, history, and PIN checks in `ReceiveController`.

## Components

- `ReceiveTab`: adds the QR action and opens the dialog.
- `QrDialog`: reused to render the local upload URL.
- `ReceiveController`: serves the upload page and JavaScript at local-only routes.
- Browser assets: a small HTML page and JavaScript module that build the prepare-upload request and stream selected files to the existing upload endpoint.
- API route constants: add local browser-upload route constants without changing LocalSend protocol routes.

## Data Flow

1. Windows app is on the `Receive` tab and the server is running.
2. User opens the QR dialog.
3. iPhone scans `http://<lan-ip>:<port>/upload`.
4. Browser loads the upload HTML and JavaScript from the Windows app.
5. Browser creates a v2 prepare-upload payload with a browser sender identity and selected file metadata.
6. Windows receives the prepare-upload request through existing `ReceiveController`.
7. Windows accepts through Quick Save or the normal accept/decline UI.
8. Browser uploads each file using the session id and file tokens returned by prepare-upload.
9. Windows saves files through the existing receive path.

## Privacy Boundary

All QR upload traffic is LAN-only between the iPhone browser and Windows receiver. The QR URL contains only the selected local IP address, local port, and `/upload` path. It does not include device alias, device model, fingerprint, token, public IP, or any LocalSend public-service URL.

The upload page is embedded in the app and does not load remote scripts, fonts, analytics, telemetry, ads, or external assets.

HTTP is used by default for browser compatibility on iPhone. This avoids self-signed certificate warnings. Users on untrusted networks should keep Quick Save off or configure a receive PIN.

## Error Handling

- If the server is offline or no LAN IP is available, the QR action is disabled.
- If another receive session is active, the existing prepare-upload endpoint returns `409`.
- If receive PIN is enabled, the existing PIN validation is used.
- If the recipient declines, the browser shows a rejection message.
- If upload fails, the browser shows the failing file and HTTP error status.

## Tests

Add focused tests before implementation:

- API route constants for the browser upload page and JavaScript asset.
- HTML/JavaScript asset test that verifies there are no remote URLs and that the script targets the existing v2 prepare-upload and upload endpoints.
- Widget/view-model test for the QR URL builder, covering server offline, empty IP list, and local URL generation.
- Existing full verification remains required: privacy audit, Flutter analyze, Flutter test, Rust test, Windows debug build.
