# iphone2win USB Cable Mode Design

## Goal

Add a USB cable transfer mode for offline iPhone <-> Windows file exchange while preserving all existing LAN QR transfer, browser upload, browser download, and text clipboard features.

## Non-Goals

- Do not replace or remove existing Send, Receive, QR upload, QR download, LAN discovery, or explicit text paste features.
- Do not add VPS, relay, cloud storage, public server, account login, telemetry, analytics, or hidden collection.
- Do not implement private iOS USB protocols or require device jailbreak.
- Do not attempt background clipboard sync.

## Platform Reality

iOS third-party apps cannot expose a general Android-style USB mass-storage or MTP endpoint. The supported no-network data-cable path is Apple app file sharing: when `UIFileSharingEnabled` is enabled, files in the app Documents directory are visible in Apple Devices/iTunes/Finder. The project already enables `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` in `app/ios/Runner/Info.plist`.

## User Workflow

### iPhone to Windows

1. In iphone2win on iPhone, open USB Cable Mode.
2. Pick files/photos/text/clipboard content.
3. Export them into `USB-Outbox` inside the app Documents directory.
4. Connect iPhone to Windows by cable and trust the computer.
5. Open Apple Devices on Windows, select the iPhone, open Files, select iphone2win, and copy files from `USB-Outbox`.

### Windows to iPhone

1. Connect iPhone to Windows by cable and trust the computer.
2. Open Apple Devices on Windows, select the iPhone, open Files, select iphone2win.
3. Drag files into `USB-Inbox`.
4. In iphone2win on iPhone, open USB Cable Mode and import/share/open files from `USB-Inbox`.

## App Changes

### iOS/Flutter

- Keep existing iOS file sharing keys.
- Add `USB-Inbox` and `USB-Outbox` directory helpers under the app Documents directory.
- Add a USB Cable Mode page with two sections:
  - `USB-Inbox`: list files copied from Windows.
  - `USB-Outbox`: list files exported from iPhone for Windows.
- Add actions:
  - Pick files/photos using existing picker pipeline where possible.
  - Export text/clipboard content as `.txt`.
  - Clear inbox/outbox.
  - Open/share selected files using platform share/open APIs where already available.

### Windows/Flutter

- Add the same USB Cable Mode page as a guide surface.
- Show concise steps for Apple Devices file sharing.
- Provide no device-scanning daemon and no Apple private API dependency.
- Optionally open a local folder for staging files on Windows, but do not claim direct USB filesystem access from the app.

## Data Model

- USB mode files are ordinary files in:
  - iOS: app Documents directory / `USB-Inbox` and `USB-Outbox`.
  - Windows: optional user-selected staging folder, defaulting to Downloads / `iphone2win USB`.
- No metadata database is required.
- No transfer history is required for USB mode v1.

## Privacy

- No network connection is created by USB Cable Mode.
- No public IP, alias, version, device model, fingerprint, token, or file metadata is sent to a server.
- Apple Devices/iTunes sees only files the user puts in the app Documents directory.
- Text and clipboard exports are explicit user actions and become local `.txt` files.

## Error Handling

- If Apple Devices does not show iphone2win, tell the user to trust the computer and confirm Apple Devices/iTunes is installed.
- If directory creation fails, show a local error and do not fall back to network transfer.
- If a file already exists in outbox, create a numbered filename instead of overwriting.
- If clipboard is empty, show the existing no-clipboard message.

## Testing

- Add source-level tests confirming existing QR/LAN entries remain present.
- Add source-level tests confirming iOS file sharing keys stay enabled.
- Add unit tests for USB directory naming and collision-safe filename generation.
- Add UI source tests confirming USB Cable Mode has explicit inbox/outbox actions and does not remove existing send/receive actions.
- Run existing web and branding tests before rebuilding portable Windows app.
