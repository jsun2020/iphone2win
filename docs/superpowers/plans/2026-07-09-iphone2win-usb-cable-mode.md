# iphone2win USB Cable Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an offline USB Cable Mode based on iOS app file sharing while preserving existing LAN QR transfer, browser upload/download, and explicit text clipboard features.

**Architecture:** Keep current Receive/Send/Settings flows intact and add USB as a fourth home tab. USB mode uses ordinary files in app Documents subfolders (`USB-Inbox`, `USB-Outbox`) and optional Windows staging folders; it does not open network sockets or use a server. File export logic is isolated in small utilities so UI can stay thin and testable.

**Tech Stack:** Flutter/Dart, existing `path_provider`, existing file picker/converter pipeline, iOS `UIFileSharingEnabled`, Windows portable Flutter build, Dart unit/source tests.

---

## File Structure

- Create `app/lib/util/usb/usb_cable_paths.dart`: owns USB directory constants, creates inbox/outbox/staging directories, and generates collision-safe filenames.
- Create `app/lib/util/usb/usb_cable_exporter.dart`: copies existing `CrossFile` selections or text bytes into `USB-Outbox`.
- Create `app/lib/pages/tabs/usb_tab.dart`: fourth tab UI for USB mode. It lists inbox/outbox, explains Apple Devices steps, exports selected files/text, opens folders where supported, and clears folders.
- Modify `app/lib/pages/home_page.dart`: add `HomeTab.usb`, import `UsbTab`, and append the tab without removing existing tabs.
- Modify existing generated/localized strings minimally by using local hardcoded English/Chinese-safe labels in v1, avoiding full translation regeneration churn.
- Create `app/test/unit/util/usb_cable_paths_test.dart`: validates directory names and filename collision behavior.
- Create `app/test/unit/util/usb_cable_exporter_test.dart`: validates byte/text export behavior.
- Create `app/test/unit/ui/usb_mode_preserves_existing_flows_test.dart`: verifies Receive/Send QR features remain and USB tab is additive.
- Create `app/test/unit/ui/ios_file_sharing_test.dart`: verifies iOS file sharing plist keys stay enabled.

---

### Task 1: Add Regression Tests That Protect Existing Features

**Files:**
- Create: `app/test/unit/ui/usb_mode_preserves_existing_flows_test.dart`
- Test existing: `app/test/unit/ui/receive_tab_qr_upload_test.dart`
- Test existing: `app/test/unit/ui/send_tab_qr_download_test.dart`

- [ ] **Step 1: Write the failing/additive UI source test**

```dart
import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('USB mode is additive', () {
    test('HomePage keeps existing tabs and adds USB as a fourth tab', () {
      final source = File('lib/pages/home_page.dart').readAsStringSync();

      expect(source, contains('HomeTab.receive'));
      expect(source, contains('HomeTab.send'));
      expect(source, contains('HomeTab.settings'));
      expect(source, contains('HomeTab.usb'));
      expect(source, contains('UsbTab'));
    });

    test('Receive QR upload and Send QR download entries remain wired', () {
      final receiveTab = File('lib/pages/tabs/receive_tab.dart').readAsStringSync();
      final sendTab = File('lib/pages/tabs/send_tab.dart').readAsStringSync();
      final uploadJs = File('assets/web/upload.js').readAsStringSync();
      final mainJs = File('assets/web/main.js').readAsStringSync();

      expect(receiveTab, contains("ValueKey('qr-upload-btn')"));
      expect(sendTab, contains('onTapShareViaLink'));
      expect(sendTab, contains('Icons.qr_code'));
      expect(uploadJs, contains('/api/iphone2win/v1/clipboard-text'));
      expect(mainJs, contains('copyTextFromTextarea'));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails before implementation**

Run: `dart test test/unit/ui/usb_mode_preserves_existing_flows_test.dart`

Expected: FAIL because `HomeTab.usb` and `UsbTab` do not exist yet.

- [ ] **Step 3: Keep this test green after each later task**

Run after every UI task:

```powershell
dart test test/unit/ui/usb_mode_preserves_existing_flows_test.dart test/unit/ui/receive_tab_qr_upload_test.dart test/unit/ui/send_tab_qr_download_test.dart
```

Expected after Task 4: PASS.

- [ ] **Step 4: Commit**

```powershell
git add app/test/unit/ui/usb_mode_preserves_existing_flows_test.dart
git commit -m "test: protect existing transfer flows before usb mode"
```

---

### Task 2: Add USB Directory Helpers

**Files:**
- Create: `app/lib/util/usb/usb_cable_paths.dart`
- Create: `app/test/unit/util/usb_cable_paths_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
import 'dart:io';

import 'package:localsend_app/util/usb/usb_cable_paths.dart';
import 'package:test/test.dart';

void main() {
  group('USB cable paths', () {
    test('uses stable inbox and outbox folder names', () {
      expect(usbInboxFolderName, 'USB-Inbox');
      expect(usbOutboxFolderName, 'USB-Outbox');
      expect(usbWindowsStagingFolderName, 'iphone2win USB');
    });

    test('creates collision-safe filenames', () async {
      final temp = await Directory.systemTemp.createTemp('iphone2win_usb_paths_test_');
      addTearDown(() async => temp.delete(recursive: true));

      await File('${temp.path}${Platform.pathSeparator}report.txt').writeAsString('one');
      await File('${temp.path}${Platform.pathSeparator}report (1).txt').writeAsString('two');

      final next = await getAvailableUsbFile(temp, 'report.txt');

      expect(next.path.endsWith('report (2).txt'), isTrue);
    });

    test('sanitizes path separators in filenames', () async {
      final temp = await Directory.systemTemp.createTemp('iphone2win_usb_paths_test_');
      addTearDown(() async => temp.delete(recursive: true));

      final next = await getAvailableUsbFile(temp, 'nested/name.txt');

      expect(next.path.endsWith('nested-name.txt'), isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/unit/util/usb_cable_paths_test.dart`

Expected: FAIL because `usb_cable_paths.dart` does not exist.

- [ ] **Step 3: Implement directory helper**

```dart
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:localsend_app/util/native/directories.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' as path_provider;

const usbInboxFolderName = 'USB-Inbox';
const usbOutboxFolderName = 'USB-Outbox';
const usbWindowsStagingFolderName = 'iphone2win USB';

Future<Directory> getUsbInboxDirectory() async {
  return _ensureSubDirectory(await _getUsbRootDirectory(), usbInboxFolderName);
}

Future<Directory> getUsbOutboxDirectory() async {
  return _ensureSubDirectory(await _getUsbRootDirectory(), usbOutboxFolderName);
}

Future<Directory> getUsbWindowsStagingDirectory() async {
  final downloads = await getDefaultDestinationDirectory();
  return _ensureSubDirectory(Directory(downloads), usbWindowsStagingFolderName);
}

Future<File> getAvailableUsbFile(Directory directory, String fileName) async {
  final safeName = _sanitizeFileName(fileName);
  final extension = p.extension(safeName);
  final baseName = p.basenameWithoutExtension(safeName);

  var candidate = File(p.join(directory.path, safeName));
  var counter = 1;
  while (await candidate.exists()) {
    candidate = File(p.join(directory.path, '$baseName ($counter)$extension'));
    counter++;
  }
  return candidate;
}

Future<Directory> _getUsbRootDirectory() async {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return path_provider.getApplicationDocumentsDirectory();
  }
  return Directory(await getDefaultDestinationDirectory());
}

Future<Directory> _ensureSubDirectory(Directory parent, String childName) async {
  final directory = Directory(p.join(parent.path, childName));
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }
  return directory;
}

String _sanitizeFileName(String fileName) {
  final name = fileName.trim().isEmpty ? 'file' : fileName.trim();
  return name.replaceAll(RegExp(r'[\\/]+'), '-');
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `dart test test/unit/util/usb_cable_paths_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add app/lib/util/usb/usb_cable_paths.dart app/test/unit/util/usb_cable_paths_test.dart
git commit -m "feat: add usb cable directory helpers"
```

---

### Task 3: Add USB Exporter

**Files:**
- Create: `app/lib/util/usb/usb_cable_exporter.dart`
- Create: `app/test/unit/util/usb_cable_exporter_test.dart`

- [ ] **Step 1: Write failing exporter tests**

```dart
import 'dart:io';

import 'package:common/model/file_type.dart';
import 'package:localsend_app/model/cross_file.dart';
import 'package:localsend_app/util/usb/usb_cable_exporter.dart';
import 'package:test/test.dart';

void main() {
  group('USB cable exporter', () {
    test('exports in-memory text bytes', () async {
      final outbox = await Directory.systemTemp.createTemp('iphone2win_usb_exporter_test_');
      addTearDown(() async => outbox.delete(recursive: true));

      final exported = await exportCrossFilesToUsbOutbox(
        outbox: outbox,
        files: [
          CrossFile(
            name: 'message.txt',
            fileType: FileType.text,
            size: 5,
            thumbnail: null,
            asset: null,
            path: null,
            bytes: 'hello'.codeUnits,
            lastModified: null,
            lastAccessed: null,
          ),
        ],
      );

      expect(exported, hasLength(1));
      expect(await File(exported.single).readAsString(), 'hello');
    });

    test('copies file path contents without overwriting existing files', () async {
      final temp = await Directory.systemTemp.createTemp('iphone2win_usb_exporter_test_');
      final outbox = Directory('${temp.path}${Platform.pathSeparator}outbox')..createSync();
      final source = File('${temp.path}${Platform.pathSeparator}photo.jpg')..writeAsStringSync('image');
      File('${outbox.path}${Platform.pathSeparator}photo.jpg').writeAsStringSync('existing');
      addTearDown(() async => temp.delete(recursive: true));

      final exported = await exportCrossFilesToUsbOutbox(
        outbox: outbox,
        files: [
          CrossFile(
            name: 'photo.jpg',
            fileType: FileType.image,
            size: 5,
            thumbnail: null,
            asset: null,
            path: source.path,
            bytes: null,
            lastModified: null,
            lastAccessed: null,
          ),
        ],
      );

      expect(exported.single.endsWith('photo (1).jpg'), isTrue);
      expect(await File(exported.single).readAsString(), 'image');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/unit/util/usb_cable_exporter_test.dart`

Expected: FAIL because `usb_cable_exporter.dart` does not exist.

- [ ] **Step 3: Implement exporter**

```dart
import 'dart:io';

import 'package:localsend_app/model/cross_file.dart';
import 'package:localsend_app/util/usb/usb_cable_paths.dart';

Future<List<String>> exportCrossFilesToUsbOutbox({
  required Directory outbox,
  required List<CrossFile> files,
}) async {
  if (!await outbox.exists()) {
    await outbox.create(recursive: true);
  }

  final exported = <String>[];
  for (final file in files) {
    final target = await getAvailableUsbFile(outbox, file.name);
    if (file.bytes != null) {
      await target.writeAsBytes(file.bytes!, flush: true);
    } else if (file.path != null) {
      await File(file.path!).copy(target.path);
    } else {
      continue;
    }
    exported.add(target.path);
  }
  return exported;
}

Future<String> exportTextToUsbOutbox({
  required Directory outbox,
  required String text,
  String fileName = 'clipboard.txt',
}) async {
  final target = await getAvailableUsbFile(outbox, fileName);
  await target.writeAsString(text, flush: true);
  return target.path;
}
```

- [ ] **Step 4: Run exporter tests**

Run: `dart test test/unit/util/usb_cable_exporter_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add app/lib/util/usb/usb_cable_exporter.dart app/test/unit/util/usb_cable_exporter_test.dart
git commit -m "feat: export files to usb outbox"
```

---

### Task 4: Add USB Tab Without Removing Existing Tabs

**Files:**
- Create: `app/lib/pages/tabs/usb_tab.dart`
- Modify: `app/lib/pages/home_page.dart`

- [ ] **Step 1: Implement `UsbTab`**

Create a stateful tab that refreshes inbox/outbox on open and after actions. Use hardcoded v1 labels to avoid translation churn:

```dart
class UsbTab extends StatefulWidget {
  const UsbTab({super.key});

  @override
  State<UsbTab> createState() => _UsbTabState();
}
```

The page must include:
- Title: `USB Cable Mode`
- Instruction text mentioning `Apple Devices`, `Files`, `iphone2win`, `USB-Inbox`, `USB-Outbox`
- Buttons:
  - `Refresh`
  - `Open USB folder` on desktop platforms
  - `Export selected files`
  - `Export clipboard text`
  - `Clear USB-Outbox`
- Lists for `USB-Inbox` and `USB-Outbox`.

- [ ] **Step 2: Wire USB as fourth tab**

Modify `HomeTab`:

```dart
enum HomeTab {
  receive(Icons.wifi),
  send(Icons.send),
  usb(Icons.usb),
  settings(Icons.settings);
}
```

Modify label switch:

```dart
case HomeTab.usb:
  return 'USB';
```

Modify `PageView.children`:

```dart
children: const [
  SafeArea(child: ReceiveTab()),
  SafeArea(child: SendTab()),
  SafeArea(child: UsbTab()),
  SettingsTab(),
],
```

- [ ] **Step 3: Run regression tests**

Run:

```powershell
dart test test/unit/ui/usb_mode_preserves_existing_flows_test.dart test/unit/ui/receive_tab_qr_upload_test.dart test/unit/ui/send_tab_qr_download_test.dart
```

Expected: PASS.

- [ ] **Step 4: Commit**

```powershell
git add app/lib/pages/home_page.dart app/lib/pages/tabs/usb_tab.dart
git commit -m "feat: add usb cable mode tab"
```

---

### Task 5: Verify iOS File Sharing Configuration

**Files:**
- Create: `app/test/unit/ui/ios_file_sharing_test.dart`

- [ ] **Step 1: Write plist guard test**

```dart
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('iOS app file sharing remains enabled for USB Cable Mode', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(plist, contains('<key>UIFileSharingEnabled</key>'));
    expect(plist, contains('<true/>'));
    expect(plist, contains('<key>LSSupportsOpeningDocumentsInPlace</key>'));
  });
}
```

- [ ] **Step 2: Run test**

Run: `dart test test/unit/ui/ios_file_sharing_test.dart`

Expected: PASS without modifying `Info.plist`, because the keys are already present.

- [ ] **Step 3: Commit**

```powershell
git add app/test/unit/ui/ios_file_sharing_test.dart
git commit -m "test: guard ios usb file sharing keys"
```

---

### Task 6: Full Verification and Portable Build

**Files:**
- Update: `dist/iphone2win-portable.exe`
- Update: `dist/iphone2win-portable-files.zip`

- [ ] **Step 1: Format and analyze**

Run:

```powershell
dart format lib/pages/home_page.dart lib/pages/tabs/usb_tab.dart lib/util/usb/usb_cable_paths.dart lib/util/usb/usb_cable_exporter.dart test/unit/ui/usb_mode_preserves_existing_flows_test.dart test/unit/ui/ios_file_sharing_test.dart test/unit/util/usb_cable_paths_test.dart test/unit/util/usb_cable_exporter_test.dart
dart analyze lib/pages/home_page.dart lib/pages/tabs/usb_tab.dart lib/util/usb/usb_cable_paths.dart lib/util/usb/usb_cable_exporter.dart test/unit/ui/usb_mode_preserves_existing_flows_test.dart test/unit/ui/ios_file_sharing_test.dart test/unit/util/usb_cable_paths_test.dart test/unit/util/usb_cable_exporter_test.dart
```

Expected: no analyzer issues.

- [ ] **Step 2: Run targeted tests**

Run:

```powershell
dart test test/unit/util/usb_cable_paths_test.dart test/unit/util/usb_cable_exporter_test.dart test/unit/ui/usb_mode_preserves_existing_flows_test.dart test/unit/ui/ios_file_sharing_test.dart test/unit/web test/unit/ui/receive_tab_qr_upload_test.dart test/unit/ui/send_tab_qr_download_test.dart test/unit/ui/branding_name_test.dart
```

Expected: all tests pass.

- [ ] **Step 3: Build Windows release**

Run:

```powershell
flutter build windows --release
```

Expected: `build\windows\x64\runner\Release\iphone2win.exe` is produced.

- [ ] **Step 4: Update portable zip**

Run:

```powershell
Compress-Archive -Path build/windows/x64/runner/Release/* -DestinationPath ..\dist\iphone2win-portable-files.zip -Force
```

Expected: `dist\iphone2win-portable-files.zip` is updated.

- [ ] **Step 5: Update portable exe with the existing IExpress packaging flow**

Use the same IExpress packaging approach from the previous build: include `iphone2win-portable-files.zip` and `run_iphone2win.cmd`; verify `/Q /T:<temp> /C` extracts both files.

Expected:
- `dist\iphone2win-portable.exe` exists.
- SFX extraction contains `iphone2win-portable-files.zip`.
- SFX extraction contains `run_iphone2win.cmd`.

- [ ] **Step 6: Print SHA256 hashes**

Run:

```powershell
Get-FileHash -Algorithm SHA256 -LiteralPath ..\dist\iphone2win-portable.exe,..\dist\iphone2win-portable-files.zip | ForEach-Object { "$($_.Hash)  $($_.Path)" }
```

Expected: full SHA256 hashes are printed for final response.

- [ ] **Step 7: Commit**

```powershell
git add app/lib app/test docs dist
git commit -m "feat: add usb cable transfer mode"
```

---

## Self-Review

- Spec coverage: The plan preserves existing QR/LAN/text flows, adds USB Inbox/Outbox directories, adds iOS file sharing guards, adds a fourth tab, and rebuilds portable artifacts.
- Placeholder scan: No implementation step depends on an undefined TBD item.
- Type consistency: The helper names `getUsbInboxDirectory`, `getUsbOutboxDirectory`, `getUsbWindowsStagingDirectory`, `getAvailableUsbFile`, `exportCrossFilesToUsbOutbox`, and `exportTextToUsbOutbox` are consistent across tests and implementation.
