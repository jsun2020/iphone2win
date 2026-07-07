# iphone2win Privacy Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a LAN-only, privacy-hardened iphone2win fork that keeps Apple-device and Windows-device file transfer while removing LocalSend public signaling/STUN defaults and in-app-purchase donation dependencies.

**Architecture:** Keep the existing LocalSend local discovery and direct HTTP/HTTPS transfer path. Remove public-service startup behavior, remove purchase/donation surfaces, and add a repository privacy audit that blocks banned public hosts and non-FOSS store dependencies from active app paths.

**Tech Stack:** Flutter/Dart app, Refena state management, Rust core through flutter_rust_bridge, PowerShell and shell audit scripts, Flutter test/analyze tooling.

---

## File Structure

- Create `scripts/privacy_audit.ps1`: Windows-first static privacy guard.
- Create `scripts/privacy_audit.sh`: POSIX equivalent for contributors outside Windows.
- Modify `app/pubspec.yaml`: remove `in_app_purchase`.
- Modify `app/pubspec.lock`: regenerate with `flutter pub get`.
- Modify `app/lib/config/init.dart`: remove purchase provider import, purchase stream startup, signaling provider import, and signaling startup dispatch.
- Modify `app/lib/pages/tabs/settings_tab.dart`: remove donation/support, LocalSend privacy-policy, and Apple EULA external links from settings.
- Delete `app/lib/provider/purchase_provider.dart`: remove store purchase provider.
- Delete `app/lib/model/state/purchase_state.dart`: remove purchase state and product IDs.
- Delete `app/lib/model/state/purchase_state.mapper.dart`: remove generated purchase state mapper.
- Delete `app/lib/pages/donation/donation_page.dart`: remove donation UI and external donation links.
- Delete `app/lib/pages/donation/donation_page_vm.dart`: remove donation view model.
- Modify `app/lib/provider/network/webrtc/signaling_provider.dart`: make signaling inert and remove public-service defaults.
- Delete `app/lib/provider/network/webrtc/webrtc_receiver.dart`: remove the public-signaling receive path.
- Delete `app/lib/provider/network/webrtc/webrtc_receiver.mapper.dart`: remove generated mapper for the removed WebRTC receiver provider.
- Modify `core/src/main.rs`: remove public signaling/STUN sample defaults from the executable test harness.
- Modify generated platform files only through `flutter pub get` or Flutter build output where possible.
- Create `docs/privacy.md`: document allowed LAN-only network behavior and disallowed public egress.
- Modify `README.md`: identify the fork as iphone2win and link to the privacy boundary.

## Task 1: Add Privacy Audit Guard

**Files:**
- Create: `scripts/privacy_audit.ps1`
- Create: `scripts/privacy_audit.sh`

- [ ] **Step 1: Add the PowerShell privacy audit**

Create `scripts/privacy_audit.ps1` with this content:

```powershell
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot

$scanRoots = @(
  'app/lib',
  'app/pubspec.yaml',
  'app/pubspec.lock',
  'app/ios',
  'app/macos',
  'app/windows',
  'app/rust/src',
  'core/src',
  'server'
)

$bannedPatterns = @(
  'public\.localsend\.org',
  'stun\.localsend\.org',
  'stun\.l\.google\.com',
  'in_app_purchase',
  'in_app_purchase_storekit',
  'firebase_analytics',
  'firebase_crashlytics',
  'sentry_flutter',
  'crashlytics',
  'google_mobile_ads',
  'appsflyer',
  'mixpanel',
  'posthog'
)

$files = foreach ($scanRoot in $scanRoots) {
  $path = Join-Path $repoRoot $scanRoot
  if (Test-Path -LiteralPath $path -PathType Leaf) {
    Get-Item -LiteralPath $path
  } elseif (Test-Path -LiteralPath $path -PathType Container) {
    Get-ChildItem -LiteralPath $path -Recurse -File |
      Where-Object {
        $_.FullName -notmatch '\\build\\' -and
        $_.FullName -notmatch '\\.dart_tool\\' -and
        $_.FullName -notmatch '\\Flutter\\ephemeral\\'
      }
  }
}

$hits = @()
foreach ($file in $files) {
  foreach ($pattern in $bannedPatterns) {
    $matches = Select-String -LiteralPath $file.FullName -Pattern $pattern -CaseSensitive:$false
    foreach ($match in $matches) {
      $hits += [PSCustomObject]@{
        Path = Resolve-Path -LiteralPath $file.FullName -Relative
        Line = $match.LineNumber
        Pattern = $pattern
        Text = $match.Line.Trim()
      }
    }
  }
}

if ($hits.Count -gt 0) {
  Write-Host 'Privacy audit failed. Banned public-service or proprietary dependency references remain:'
  $hits | Format-Table -AutoSize | Out-String | Write-Host
  exit 1
}

Write-Host 'Privacy audit passed.'
```

- [ ] **Step 2: Add the shell privacy audit**

Create `scripts/privacy_audit.sh` with this content:

```sh
#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

patterns='public\.localsend\.org|stun\.localsend\.org|stun\.l\.google\.com|in_app_purchase|in_app_purchase_storekit|firebase_analytics|firebase_crashlytics|sentry_flutter|crashlytics|google_mobile_ads|appsflyer|mixpanel|posthog'

paths='app/lib app/pubspec.yaml app/pubspec.lock app/ios app/macos app/windows app/rust/src core/src server'

cd "$repo_root"

hits="$(find $paths -type f 2>/dev/null | grep -v '/build/' | grep -v '/.dart_tool/' | grep -v '/Flutter/ephemeral/' | xargs grep -Eni "$patterns" || true)"

if [ -n "$hits" ]; then
  printf '%s\n' 'Privacy audit failed. Banned public-service or proprietary dependency references remain:'
  printf '%s\n' "$hits"
  exit 1
fi

printf '%s\n' 'Privacy audit passed.'
```

- [ ] **Step 3: Run the audit and confirm it fails on current upstream code**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\privacy_audit.ps1
```

Expected: FAIL. The output includes references such as `public.localsend.org`, `stun.localsend.org`, and `in_app_purchase`.

- [ ] **Step 4: Commit the failing audit guard**

```powershell
git add scripts/privacy_audit.ps1 scripts/privacy_audit.sh
git commit -m "test: add privacy audit guard"
```

## Task 2: Remove Store Purchase Dependency And Donation Entry Points

**Files:**
- Modify: `app/pubspec.yaml`
- Modify: `app/lib/config/init.dart`
- Modify: `app/lib/pages/tabs/settings_tab.dart`
- Delete: `app/lib/provider/purchase_provider.dart`
- Delete: `app/lib/model/state/purchase_state.dart`
- Delete: `app/lib/model/state/purchase_state.mapper.dart`
- Delete: `app/lib/pages/donation/donation_page.dart`
- Delete: `app/lib/pages/donation/donation_page_vm.dart`
- Modify after command: `app/pubspec.lock`

- [ ] **Step 1: Remove the dependency line from `app/pubspec.yaml`**

Delete this dependency:

```yaml
  in_app_purchase: 3.2.0 # [FOSS_REMOVE]
```

- [ ] **Step 2: Remove purchase imports and startup from `app/lib/config/init.dart`**

Remove this import block:

```dart
// [FOSS_REMOVE_START]
import 'package:localsend_app/provider/purchase_provider.dart';

// [FOSS_REMOVE_END]
```

Remove this startup block from `postInit`:

```dart
  // [FOSS_REMOVE_START]
  if (checkPlatformSupportPayment()) {
    // ignore: unawaited_futures
    ref.redux(purchaseProvider).dispatchAsync(InitPurchaseStream());
  }
  // [FOSS_REMOVE_END]
```

- [ ] **Step 3: Remove donation and public policy links from `app/lib/pages/tabs/settings_tab.dart`**

Remove these imports:

```dart
import 'package:localsend_app/pages/donation/donation_page.dart';
import 'package:url_launcher/url_launcher.dart';
```

Remove these settings entries:

```dart
                      _ButtonEntry(
                        label: t.settingsTab.other.support,
                        buttonLabel: t.settingsTab.other.donate,
                        onTap: () async {
                          await context.push(() => const DonationPage());
                        },
                      ),
                      _ButtonEntry(
                        label: t.settingsTab.other.privacyPolicy,
                        buttonLabel: t.general.open,
                        onTap: () async {
                          await launchUrl(
                            Uri.parse('https://localsend.org/privacy'),
                            mode: LaunchMode.externalApplication,
                          );
                        },
                      ),
                      if (checkPlatform([TargetPlatform.iOS, TargetPlatform.macOS]))
                        _ButtonEntry(
                          label: t.settingsTab.other.termsOfUse,
                          buttonLabel: t.general.open,
                          onTap: () async {
                            await launchUrl(
                              Uri.parse('https://www.apple.com/legal/internet-services/itunes/dev/stdeula/'),
                              mode: LaunchMode.externalApplication,
                            );
                          },
                        ),
```

- [ ] **Step 4: Delete purchase and donation files**

```powershell
Remove-Item -LiteralPath .\app\lib\provider\purchase_provider.dart
Remove-Item -LiteralPath .\app\lib\model\state\purchase_state.dart
Remove-Item -LiteralPath .\app\lib\model\state\purchase_state.mapper.dart
Remove-Item -LiteralPath .\app\lib\pages\donation\donation_page.dart
Remove-Item -LiteralPath .\app\lib\pages\donation\donation_page_vm.dart
```

- [ ] **Step 5: Regenerate Flutter package metadata**

Run:

```powershell
Set-Location .\app
flutter pub get
Set-Location ..
```

Expected: command completes and `app/pubspec.lock` no longer contains `in_app_purchase` or `in_app_purchase_storekit`.

- [ ] **Step 6: Run targeted checks**

Run:

```powershell
rg -n "in_app_purchase|purchaseProvider|InitPurchaseStream|DonationPage|donation_page|github.com/sponsors|ko-fi.com" app\lib app\pubspec.yaml app\pubspec.lock app\ios app\macos
```

Expected: no matches in active source or dependency files.

- [ ] **Step 7: Commit purchase and donation removal**

```powershell
git add app/pubspec.yaml app/pubspec.lock app/lib/config/init.dart app/lib/pages/tabs/settings_tab.dart app/ios app/macos
git add -u app/lib/provider/purchase_provider.dart app/lib/model/state/purchase_state.dart app/lib/model/state/purchase_state.mapper.dart app/lib/pages/donation/donation_page.dart app/lib/pages/donation/donation_page_vm.dart
git commit -m "refactor: remove store donation purchases"
```

## Task 3: Disable LocalSend Public Signaling At Startup

**Files:**
- Modify: `app/lib/config/init.dart`
- Modify: `app/lib/provider/network/webrtc/signaling_provider.dart`
- Delete: `app/lib/provider/network/webrtc/webrtc_receiver.dart`
- Delete: `app/lib/provider/network/webrtc/webrtc_receiver.mapper.dart`
- Modify: `core/src/main.rs`

- [ ] **Step 1: Remove signaling startup from `app/lib/config/init.dart`**

Remove this import:

```dart
import 'package:localsend_app/provider/network/webrtc/signaling_provider.dart';
```

Remove this line from `postInit`:

```dart
  ref.redux(signalingProvider).dispatch(SetupSignalingConnection());
```

- [ ] **Step 2: Replace `app/lib/provider/network/webrtc/signaling_provider.dart` with an inert provider**

Use this complete file content:

```dart
import 'package:dart_mappable/dart_mappable.dart';
import 'package:refena_flutter/refena_flutter.dart';

part 'signaling_provider.mapper.dart';

@MappableClass()
class SignalingState with SignalingStateMappable {
  final List<String> signalingServers;
  final List<String> stunServers;

  const SignalingState({
    required this.signalingServers,
    required this.stunServers,
  });
}

final signalingProvider = ReduxProvider<SignalingService, SignalingState>((ref) {
  return SignalingService();
});

class SignalingService extends ReduxNotifier<SignalingState> {
  @override
  SignalingState init() {
    return const SignalingState(
      signalingServers: [],
      stunServers: [],
    );
  }
}

class SetupSignalingConnection extends ReduxAction<SignalingService, SignalingState> {
  @override
  SignalingState reduce() {
    return state;
  }
}
```

- [ ] **Step 3: Delete the WebRTC receive provider files**

```powershell
Remove-Item -LiteralPath .\app\lib\provider\network\webrtc\webrtc_receiver.dart
Remove-Item -LiteralPath .\app\lib\provider\network\webrtc\webrtc_receiver.mapper.dart
```

- [ ] **Step 4: Remove public signaling sample defaults from `core/src/main.rs`**

In `main`, remove this line:

```rust
    webrtc_test().await?;
```

In `webrtc_test`, replace the public URI and public STUN example with loopback-only values:

```rust
    let connection =
        webrtc::signaling::SignalingConnection::connect("ws://127.0.0.1:53318/v1/ws", &info)
            .await?;
```

```rust
        let stun_servers = vec!["stun:127.0.0.1:3478".to_string()];
```

- [ ] **Step 5: Regenerate Dart mapper files**

Run:

```powershell
Set-Location .\app
dart run build_runner build -d
Set-Location ..
```

Expected: generated mapper files compile with the simplified `SignalingState`.

- [ ] **Step 6: Run targeted signaling checks**

Run:

```powershell
rg -n "public\.localsend\.org|stun\.localsend\.org|stun\.l\.google\.com|SetupSignalingConnection\(\)|connect\(\\s*uri:|ProposingClientInfo|RegisterSignalingDeviceAction" app\lib core\src
```

Expected: no public host matches. `SetupSignalingConnection` may remain only as an inert class declaration. `RegisterSignalingDeviceAction` may remain in local state code but has no startup path.

- [ ] **Step 7: Commit signaling hardening**

```powershell
git add app/lib/config/init.dart app/lib/provider/network/webrtc/signaling_provider.dart app/lib/provider/network/webrtc/signaling_provider.mapper.dart core/src/main.rs
git add -u app/lib/provider/network/webrtc/webrtc_receiver.dart app/lib/provider/network/webrtc/webrtc_receiver.mapper.dart
git commit -m "refactor: disable public signaling startup"
```

## Task 4: Add User-Facing Privacy Documentation

**Files:**
- Create: `docs/privacy.md`
- Modify: `README.md`

- [ ] **Step 1: Create `docs/privacy.md`**

Create `docs/privacy.md` with this content:

```markdown
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
```

- [ ] **Step 2: Update the top of `README.md`**

Replace the opening title and first product paragraph with:

```markdown
# iphone2win

iphone2win is a privacy-hardened LocalSend fork for LAN-only file transfer between Apple devices and Windows devices.

This fork removes LocalSend public signaling/STUN defaults and store donation purchases. See [docs/privacy.md](docs/privacy.md) for the enforced privacy boundary.
```

Keep the upstream license and protocol information unless it conflicts with the LAN-only privacy boundary.

- [ ] **Step 3: Commit documentation**

```powershell
git add README.md docs/privacy.md
git commit -m "docs: document lan-only privacy boundary"
```

## Task 5: Run Full Verification And Fix Build Fallout

**Files:**
- Modify only files needed to resolve concrete analyzer, test, or dependency failures.

- [ ] **Step 1: Run the privacy audit**

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\privacy_audit.ps1
```

Expected: PASS.

- [ ] **Step 2: Run dependency resolution**

```powershell
Set-Location .\app
flutter pub get
Set-Location ..
```

Expected: succeeds without `in_app_purchase` in `app/pubspec.lock`.

- [ ] **Step 3: Run code generation**

```powershell
Set-Location .\app
dart run build_runner build -d
Set-Location ..
```

Expected: succeeds. Generated mapper output reflects the simplified signaling provider and removed purchase state.

- [ ] **Step 4: Run Flutter analysis**

```powershell
Set-Location .\app
flutter analyze
Set-Location ..
```

Expected: no errors.

- [ ] **Step 5: Run Flutter unit tests**

```powershell
Set-Location .\app
flutter test
Set-Location ..
```

Expected: all existing unit tests pass.

- [ ] **Step 6: Run Rust checks for the app crate**

```powershell
cargo test --manifest-path .\app\rust\Cargo.toml
```

Expected: Rust app crate compiles and tests pass.

- [ ] **Step 7: Build Windows debug target**

```powershell
Set-Location .\app
flutter build windows --debug
Set-Location ..
```

Expected: Windows debug build succeeds.

- [ ] **Step 8: Record iOS verification limitation on Windows**

On Windows, do not claim an iOS simulator build was run. Record this in the final implementation summary:

```text
iOS build not run locally because this workspace is Windows. The iOS StoreKit plugin references were removed from Flutter dependency and Pod lock files by dependency regeneration.
```

- [ ] **Step 9: Commit verification fallout fixes**

If verification required code changes, commit them:

```powershell
git add -A
git commit -m "fix: resolve privacy hardening build fallout"
```

If no files changed, do not create an empty commit.

## Task 6: Final Privacy Evidence Snapshot

**Files:**
- Create: `docs/privacy-audit-results.md`

- [ ] **Step 1: Create `docs/privacy-audit-results.md`**

Create the file with this content after verification commands have run:

```markdown
# Privacy Audit Results

This snapshot records the privacy-hardening verification for iphone2win.

Commands run:

- `powershell -ExecutionPolicy Bypass -File .\scripts\privacy_audit.ps1`
- `flutter pub get`
- `dart run build_runner build -d`
- `flutter analyze`
- `flutter test`
- `cargo test --manifest-path .\app\rust\Cargo.toml`
- `flutter build windows --debug`

Expected privacy outcome:

- No LocalSend public signaling host remains in active app paths.
- No LocalSend public STUN host remains in active app paths.
- No Google public STUN sample remains in scanned paths.
- No `in_app_purchase` dependency remains.
- No generated StoreKit purchase plugin remains.
- No known analytics, crash reporting, ads, or telemetry SDK reference remains in active app paths.

iOS build note:

- iOS build verification requires macOS and Xcode. This Windows workspace cannot run the iOS simulator or App Store build locally.
```

- [ ] **Step 2: Commit the evidence snapshot**

```powershell
git add docs/privacy-audit-results.md
git commit -m "docs: record privacy audit results"
```

- [ ] **Step 3: Final repository state check**

```powershell
git status --short
git log --oneline -5
```

Expected: clean working tree, with recent commits for design, plan, privacy audit, purchase removal, signaling hardening, documentation, and verification evidence.
