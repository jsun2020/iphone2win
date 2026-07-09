# iphone2win Automatic USB Sync Design

## Goal

Add an automatic USB transfer path for iPhone and Windows while preserving the existing LAN, QR, browser text, and manual USB staging flows.

The Windows app will use a bundled FOSS libimobiledevice command-line toolset to access the iPhone app's File Sharing Documents directory over USB. The feature must not use a relay server, public network service, remote telemetry, or hidden device information collection.

## Non-Goals

- Do not expose the full iPhone filesystem as a Windows drive.
- Do not read Photos/DCIM through this feature; Windows already exposes that separately through the PTP/DCIM path.
- Do not access other iOS app containers.
- Do not require jailbreak, iCloud, Wi-Fi sync, or a VPS.
- Do not commit bundled executable tools, DLLs, build outputs, zips, or portable release artifacts to git.

## External Requirements

The user's Windows computer must have Apple Mobile Device USB driver support installed through Apple Devices or iTunes. The app can detect a missing driver and explain the required install, but it will not bundle Apple's proprietary driver.

The portable package may include a local `tools/libimobiledevice/` folder with FOSS command-line tools and DLLs. This directory is treated as a release-time dependency folder and ignored by git.

## Protocol Scope

The implementation uses libimobiledevice's local USB protocol stack:

- `idevice_id` to detect attached devices.
- `idevicepair` to check or trigger pairing/trust state.
- `afcclient --documents <bundleId>` to access the Documents directory of the iOS app that has File Sharing enabled.

The relevant upstream capability is iOS AFC/HouseArrest access to File Sharing app Documents. libimobiledevice documents this as access to "documents of file sharing apps" and `afcclient --documents <appid>`.

References:

- https://libimobiledevice.org/
- https://github.com/libimobiledevice/libimobiledevice
- https://man.archlinux.org/man/extra/libimobiledevice/afcclient.1.en
- https://docs.libimobiledevice.org/libimobiledevice/latest/house__arrest_8h.html

## App Identifier

The current iOS bundle identifier in the project is still:

```text
org.localsend.localsendApp
```

The UI brand is `iphone2win`, but the first automatic USB sync implementation must use this existing bundle id when talking to iOS File Sharing. Changing the iOS bundle id is a separate migration because it affects app identity, entitlements, installed app matching, and user data continuity.

## Directory Model

The iPhone app Documents directory contains:

- `USB-Inbox`: files pushed from Windows to iPhone.
- `USB-Outbox`: files prepared on iPhone for Windows to pull.

The Windows app already has local staging folders:

- `USB-Inbox`
- `USB-Outbox`

Automatic sync adds direct iPhone-side operations:

- Pull iPhone `USB-Outbox` into the Windows destination folder.
- Push selected Windows files into iPhone `USB-Inbox`.
- Optionally list iPhone `USB-Inbox` and `USB-Outbox` in the USB tab.

Manual staging remains available as a fallback.

## Components

### Tool Resolver

Create a small resolver that finds libimobiledevice tools in this order:

1. `tools/libimobiledevice/` next to the running executable or project root during development.
2. `PATH`, as a developer fallback.

It reports missing tool names explicitly. It must not download tools automatically.

### Command Runner

Create an isolated process wrapper for USB commands:

- Accepts executable path, arguments, timeout, and working directory.
- Captures stdout, stderr, and exit code.
- Redacts or avoids logging full device identifiers unless needed for user action.
- Never invokes commands through shell string concatenation.

### Device Service

Create a service for USB device state:

- Detect connected device count.
- Show status: no tool, no driver/device, device connected, not trusted, paired/trusted, app Documents unavailable.
- Run pair/validate operations.
- Keep errors user-readable.

### File Sharing Service

Create a service for app Documents operations:

- List remote `USB-Inbox` and `USB-Outbox`.
- Create remote folders if missing.
- Pull remote files from `USB-Outbox` to Windows.
- Push local files to `USB-Inbox`.
- Preserve file names safely using the existing Windows-safe filename helper where local paths are created.

The first implementation may use `afcclient` batch or single-command mode if available in the bundled version. If the selected `afcclient` build is interactive-only, add a local adapter that feeds a command script through stdin and validates output.

### UI Integration

Extend the existing USB tab with a new "Automatic USB" area:

- `Detect iPhone`
- `Check trust`
- `Pull from iPhone`
- `Push selected files to iPhone`
- Device/app status text
- Last action result

Keep the current manual `USB-Inbox` and `USB-Outbox` local staging UI below or alongside it.

## Error Handling

The app should distinguish these cases:

- Bundled tools missing.
- Apple Mobile Device driver missing or unavailable.
- No iPhone connected.
- iPhone connected but not trusted.
- More than one device connected.
- `iphone2win` iOS app not installed or bundle id mismatch.
- iOS File Sharing Documents unavailable.
- Remote folder missing, with auto-create attempted.
- File copy failed.

Each error should give the next action in plain language.

## Privacy and Security

- No internet access is required by this feature.
- No remote server is contacted.
- No device discovery information is sent outside the computer.
- Device identifiers are used only locally to address the connected iPhone and should not be shown in full unless required for troubleshooting.
- Access is limited to the configured app's File Sharing Documents directory.
- Other iOS app containers and system locations are out of scope.

## Packaging

Git tracks only source, tests, and docs.

Ignored release-time folders/files:

- `/dist/`
- `/tools/libimobiledevice/`

Portable packaging should include:

- Windows release app files.
- `tools/libimobiledevice/` FOSS command-line tools and DLLs when present.
- The existing run script.

If tools are missing during packaging, the package can still be built, but the USB tab should show that automatic USB tools are unavailable and manual USB mode remains available.

## Testing

Use test-first implementation for new logic.

Source/unit tests:

- Tool resolver finds bundled tools and falls back to PATH.
- Tool resolver reports missing tools.
- Command runner passes arguments without shell concatenation.
- Device status parser maps command outcomes to user states.
- File operation builder uses `--documents org.localsend.localsendApp`.
- USB tab source guard keeps old LAN/QR/text/manual USB controls.
- `.gitignore` guard ensures `dist/` and `tools/libimobiledevice/` are ignored.

Manual verification:

- With no tools: app shows missing tools.
- With tools but no iPhone: app shows no device.
- With iPhone untrusted: app asks user to trust this computer.
- With trusted iPhone and app installed: list/pull/push works for `USB-Inbox` and `USB-Outbox`.
- Existing LAN QR upload/download and explicit text transfer still work.
- Portable package runs without installing the app.

## Open Implementation Constraint

The exact command syntax for non-interactive `afcclient` operations must be validated against the bundled Windows build selected for packaging. The code should isolate this in one adapter so changing command syntax does not affect the UI or higher-level services.

