# iphone2win Automatic USB Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an automatic USB transfer mode that uses bundled libimobiledevice tools to push/pull files between Windows and the iPhone app's File Sharing Documents directory.

**Architecture:** Keep the existing manual USB staging UI and add a separate automatic USB service layer. The service layer resolves bundled tools, runs commands without shell string concatenation, maps USB/pairing/app states to user-readable statuses, and isolates AFC command syntax behind a small adapter.

**Tech Stack:** Flutter/Dart, `dart:io` process APIs, existing `path` and `CrossFile` models, bundled external libimobiledevice CLI tools at release time, source/unit tests.

---

## File Structure

- Modify `.gitignore`: ignore `/tools/libimobiledevice/`.
- Create `app/lib/util/usb/ios_usb_constants.dart`: bundle id, remote folder names, command names.
- Create `app/lib/util/usb/ios_usb_command.dart`: process result model and command runner using `Process.start`.
- Create `app/lib/util/usb/ios_usb_tools.dart`: bundled/PATH tool resolution.
- Create `app/lib/util/usb/ios_usb_device.dart`: device detection, trust/pair status mapping.
- Create `app/lib/util/usb/ios_usb_file_service.dart`: AFC/HouseArrest document operations.
- Modify `app/lib/pages/tabs/usb_tab.dart`: add Automatic USB controls while keeping manual controls.
- Create `app/test/unit/util/ios_usb_tools_test.dart`.
- Create `app/test/unit/util/ios_usb_command_test.dart`.
- Create `app/test/unit/util/ios_usb_device_test.dart`.
- Create `app/test/unit/util/ios_usb_file_service_test.dart`.
- Create `app/test/unit/ui/automatic_usb_sync_source_test.dart`.
- Modify or create `scripts/package_windows_portable.ps1`: include `tools/libimobiledevice` when present, but do not require it.

---

### Task 1: Git Ignore and Source Guards

**Files:**
- Modify: `.gitignore`
- Create: `app/test/unit/ui/automatic_usb_sync_source_test.dart`

- [ ] **Step 1: Write failing source tests**

Create `app/test/unit/ui/automatic_usb_sync_source_test.dart`:

```dart
import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('automatic USB sync source guards', () {
    test('root gitignore keeps generated release artifacts and bundled tools out of git', () {
      final gitignore = File('../.gitignore').readAsStringSync();

      expect(gitignore, contains('/dist/'));
      expect(gitignore, contains('/tools/libimobiledevice/'));
    });

    test('USB tab keeps manual mode and adds automatic USB actions', () {
      final source = File('lib/pages/tabs/usb_tab.dart').readAsStringSync();

      expect(source, contains('USB Cable Mode'));
      expect(source, contains('Open USB folder'));
      expect(source, contains('Export selected files'));
      expect(source, contains('Export clipboard text'));
      expect(source, contains('Clear USB-Outbox'));
      expect(source, contains('Automatic USB'));
      expect(source, contains('Detect iPhone'));
      expect(source, contains('Check trust'));
      expect(source, contains('Pull from iPhone'));
      expect(source, contains('Push selected files to iPhone'));
    });

    test('automatic USB code uses the current iOS bundle id for File Sharing documents', () {
      final source = File('lib/util/usb/ios_usb_constants.dart').readAsStringSync();

      expect(source, contains("iphone2winIosBundleId = 'org.localsend.localsendApp'"));
    });
  });
}
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```powershell
dart test test/unit/ui/automatic_usb_sync_source_test.dart
```

Expected: FAIL because `/tools/libimobiledevice/`, `Automatic USB`, and `ios_usb_constants.dart` do not exist yet.

- [ ] **Step 3: Add ignore rule and constants**

Modify root `.gitignore`:

```gitignore
# Generated portable release artifacts
/dist/

# Release-time bundled libimobiledevice binaries and DLLs
/tools/libimobiledevice/
```

Create `app/lib/util/usb/ios_usb_constants.dart`:

```dart
const iphone2winIosBundleId = 'org.localsend.localsendApp';

const iosUsbInboxFolderName = 'USB-Inbox';
const iosUsbOutboxFolderName = 'USB-Outbox';

const ideviceIdToolName = 'idevice_id';
const idevicePairToolName = 'idevicepair';
const afcClientToolName = 'afcclient';

const libimobiledeviceToolFolder = 'tools/libimobiledevice';
```

- [ ] **Step 4: Add placeholder UI strings only after services exist**

Do not modify `usb_tab.dart` in this task. The UI source test should remain partially failing until Task 5 wires the automatic controls.

- [ ] **Step 5: Run narrow test**

Run:

```powershell
dart test test/unit/ui/automatic_usb_sync_source_test.dart
```

Expected after this task: still FAIL only on missing USB tab UI strings. This proves Task 5 is needed.

- [ ] **Step 6: Commit**

```powershell
git add .gitignore app/lib/util/usb/ios_usb_constants.dart app/test/unit/ui/automatic_usb_sync_source_test.dart
git commit -m "test: guard automatic usb sync source boundaries"
```

---

### Task 2: Command Runner Without Shell Concatenation

**Files:**
- Create: `app/lib/util/usb/ios_usb_command.dart`
- Create: `app/test/unit/util/ios_usb_command_test.dart`

- [ ] **Step 1: Write failing command runner tests**

Create `app/test/unit/util/ios_usb_command_test.dart`:

```dart
import 'dart:io';

import 'package:localsend_app/util/usb/ios_usb_command.dart';
import 'package:test/test.dart';

void main() {
  group('iOS USB command runner', () {
    test('captures stdout stderr and exit code without shell mode', () async {
      final runner = ProcessIosUsbCommandRunner();
      final executable = Platform.isWindows ? 'cmd' : 'sh';
      final args = Platform.isWindows
          ? ['/c', 'echo out&& echo err 1>&2&& exit /b 7']
          : ['-c', 'echo out; echo err 1>&2; exit 7'];

      final result = await runner.run(executable, args);

      expect(result.exitCode, 7);
      expect(result.stdout.trim(), 'out');
      expect(result.stderr.trim(), 'err');
      expect(result.timedOut, isFalse);
    });

    test('passes stdin to interactive commands', () async {
      final runner = ProcessIosUsbCommandRunner();
      final executable = Platform.isWindows ? 'powershell' : 'sh';
      final args = Platform.isWindows
          ? ['-NoProfile', '-Command', r'$input | ForEach-Object { "got:$_" }']
          : ['-c', r'while read line; do echo "got:$line"; done'];

      final result = await runner.run(executable, args, stdinText: 'hello\nquit\n');

      expect(result.exitCode, 0);
      expect(result.stdout, contains('got:hello'));
      expect(result.stdout, contains('got:quit'));
    });

    test('reports timeout and kills the process', () async {
      final runner = ProcessIosUsbCommandRunner();
      final executable = Platform.isWindows ? 'powershell' : 'sh';
      final args = Platform.isWindows
          ? ['-NoProfile', '-Command', 'Start-Sleep -Seconds 5']
          : ['-c', 'sleep 5'];

      final result = await runner.run(
        executable,
        args,
        timeout: const Duration(milliseconds: 100),
      );

      expect(result.timedOut, isTrue);
      expect(result.exitCode, isNot(0));
    });
  });
}
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```powershell
dart test test/unit/util/ios_usb_command_test.dart
```

Expected: FAIL because `ios_usb_command.dart` does not exist.

- [ ] **Step 3: Implement command runner**

Create `app/lib/util/usb/ios_usb_command.dart`:

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

class IosUsbCommandResult {
  final int exitCode;
  final String stdout;
  final String stderr;
  final bool timedOut;

  const IosUsbCommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.timedOut,
  });

  bool get ok => exitCode == 0 && !timedOut;
}

abstract class IosUsbCommandRunner {
  Future<IosUsbCommandResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    String? stdinText,
    Duration timeout,
  });
}

class ProcessIosUsbCommandRunner implements IosUsbCommandRunner {
  const ProcessIosUsbCommandRunner();

  @override
  Future<IosUsbCommandResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    String? stdinText,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: false,
    );

    if (stdinText != null) {
      process.stdin.write(stdinText);
    }
    await process.stdin.close();

    final stdoutFuture = process.stdout.transform(systemEncoding.decoder).join();
    final stderrFuture = process.stderr.transform(systemEncoding.decoder).join();

    var timedOut = false;
    int exitCode;
    try {
      exitCode = await process.exitCode.timeout(timeout);
    } on TimeoutException {
      timedOut = true;
      process.kill(ProcessSignal.sigkill);
      exitCode = -1;
    }

    final stdout = await stdoutFuture;
    final stderr = await stderrFuture;
    return IosUsbCommandResult(
      exitCode: exitCode,
      stdout: stdout,
      stderr: stderr,
      timedOut: timedOut,
    );
  }
}
```

- [ ] **Step 4: Run tests**

Run:

```powershell
dart test test/unit/util/ios_usb_command_test.dart
dart analyze lib/util/usb/ios_usb_command.dart test/unit/util/ios_usb_command_test.dart
```

Expected: all command runner tests pass; analyzer reports no issues.

- [ ] **Step 5: Commit**

```powershell
git add app/lib/util/usb/ios_usb_command.dart app/test/unit/util/ios_usb_command_test.dart
git commit -m "feat: add ios usb command runner"
```

---

### Task 3: Tool Resolver for Bundled libimobiledevice

**Files:**
- Create: `app/lib/util/usb/ios_usb_tools.dart`
- Create: `app/test/unit/util/ios_usb_tools_test.dart`

- [ ] **Step 1: Write failing resolver tests**

Create `app/test/unit/util/ios_usb_tools_test.dart`:

```dart
import 'dart:io';

import 'package:localsend_app/util/usb/ios_usb_constants.dart';
import 'package:localsend_app/util/usb/ios_usb_tools.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('libimobiledevice tool resolver', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ios_usb_tools_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('finds bundled tools below tools/libimobiledevice', () async {
      final toolsDir = Directory(p.join(tempDir.path, libimobiledeviceToolFolder))..createSync(recursive: true);
      for (final tool in requiredLibimobiledeviceToolNames) {
        File(p.join(toolsDir.path, platformToolFileName(tool))).writeAsStringSync('');
      }

      final result = await LibimobiledeviceToolResolver(projectRoot: tempDir.path).resolve();

      expect(result.available, isTrue);
      expect(result.missingTools, isEmpty);
      expect(result.tools.ideviceId, p.join(toolsDir.path, platformToolFileName(ideviceIdToolName)));
      expect(result.tools.idevicePair, p.join(toolsDir.path, platformToolFileName(idevicePairToolName)));
      expect(result.tools.afcClient, p.join(toolsDir.path, platformToolFileName(afcClientToolName)));
    });

    test('reports every missing bundled tool', () async {
      Directory(p.join(tempDir.path, libimobiledeviceToolFolder)).createSync(recursive: true);

      final result = await LibimobiledeviceToolResolver(projectRoot: tempDir.path, searchPath: const []).resolve();

      expect(result.available, isFalse);
      expect(result.missingTools, containsAll(requiredLibimobiledeviceToolNames));
    });

    test('falls back to PATH entries', () async {
      final pathDir = Directory(p.join(tempDir.path, 'path-tools'))..createSync();
      for (final tool in requiredLibimobiledeviceToolNames) {
        File(p.join(pathDir.path, platformToolFileName(tool))).writeAsStringSync('');
      }

      final result = await LibimobiledeviceToolResolver(
        projectRoot: p.join(tempDir.path, 'missing-project'),
        searchPath: [pathDir.path],
      ).resolve();

      expect(result.available, isTrue);
      expect(result.tools.afcClient, p.join(pathDir.path, platformToolFileName(afcClientToolName)));
    });
  });
}
```

- [ ] **Step 2: Run test to verify failure**

Run:

```powershell
dart test test/unit/util/ios_usb_tools_test.dart
```

Expected: FAIL because `ios_usb_tools.dart` does not exist.

- [ ] **Step 3: Implement resolver**

Create `app/lib/util/usb/ios_usb_tools.dart`:

```dart
import 'dart:io';

import 'package:localsend_app/util/usb/ios_usb_constants.dart';
import 'package:path/path.dart' as p;

const requiredLibimobiledeviceToolNames = [
  ideviceIdToolName,
  idevicePairToolName,
  afcClientToolName,
];

class LibimobiledeviceTools {
  final String ideviceId;
  final String idevicePair;
  final String afcClient;

  const LibimobiledeviceTools({
    required this.ideviceId,
    required this.idevicePair,
    required this.afcClient,
  });
}

class LibimobiledeviceToolResolution {
  final LibimobiledeviceTools tools;
  final List<String> missingTools;

  const LibimobiledeviceToolResolution({
    required this.tools,
    required this.missingTools,
  });

  bool get available => missingTools.isEmpty;
}

class LibimobiledeviceToolResolver {
  final String? projectRoot;
  final List<String>? searchPath;

  const LibimobiledeviceToolResolver({
    this.projectRoot,
    this.searchPath,
  });

  Future<LibimobiledeviceToolResolution> resolve() async {
    final resolved = <String, String>{};
    final missing = <String>[];

    for (final tool in requiredLibimobiledeviceToolNames) {
      final path = await _findTool(tool);
      if (path == null) {
        missing.add(tool);
      } else {
        resolved[tool] = path;
      }
    }

    return LibimobiledeviceToolResolution(
      tools: LibimobiledeviceTools(
        ideviceId: resolved[ideviceIdToolName] ?? '',
        idevicePair: resolved[idevicePairToolName] ?? '',
        afcClient: resolved[afcClientToolName] ?? '',
      ),
      missingTools: List.unmodifiable(missing),
    );
  }

  Future<String?> _findTool(String toolName) async {
    final fileName = platformToolFileName(toolName);
    for (final root in _candidateRoots()) {
      final candidate = File(p.join(root, libimobiledeviceToolFolder, fileName));
      if (await candidate.exists()) {
        return candidate.path;
      }
    }

    for (final pathEntry in _pathEntries()) {
      final candidate = File(p.join(pathEntry, fileName));
      if (await candidate.exists()) {
        return candidate.path;
      }
    }

    return null;
  }

  Iterable<String> _candidateRoots() sync* {
    if (projectRoot != null) {
      yield projectRoot!;
    }
    yield Directory.current.path;
    yield p.dirname(Platform.resolvedExecutable);
  }

  Iterable<String> _pathEntries() {
    if (searchPath != null) {
      return searchPath!;
    }
    final path = Platform.environment['PATH'] ?? '';
    return path.split(Platform.isWindows ? ';' : ':').where((entry) => entry.isNotEmpty);
  }
}

String platformToolFileName(String toolName) {
  if (Platform.isWindows && !toolName.toLowerCase().endsWith('.exe')) {
    return '$toolName.exe';
  }
  return toolName;
}
```

- [ ] **Step 4: Run tests**

Run:

```powershell
dart test test/unit/util/ios_usb_tools_test.dart
dart analyze lib/util/usb/ios_usb_constants.dart lib/util/usb/ios_usb_tools.dart test/unit/util/ios_usb_tools_test.dart
```

Expected: tests pass; analyzer reports no issues.

- [ ] **Step 5: Commit**

```powershell
git add app/lib/util/usb/ios_usb_constants.dart app/lib/util/usb/ios_usb_tools.dart app/test/unit/util/ios_usb_tools_test.dart
git commit -m "feat: resolve bundled ios usb tools"
```

---

### Task 4: Device Detection and Pairing Status

**Files:**
- Create: `app/lib/util/usb/ios_usb_device.dart`
- Create: `app/test/unit/util/ios_usb_device_test.dart`

- [ ] **Step 1: Write failing device service tests**

Create `app/test/unit/util/ios_usb_device_test.dart`:

```dart
import 'package:localsend_app/util/usb/ios_usb_command.dart';
import 'package:localsend_app/util/usb/ios_usb_device.dart';
import 'package:localsend_app/util/usb/ios_usb_tools.dart';
import 'package:test/test.dart';

void main() {
  group('iOS USB device service', () {
    test('reports missing tools before running commands', () async {
      final service = IosUsbDeviceService(
        toolResolution: const LibimobiledeviceToolResolution(
          tools: LibimobiledeviceTools(ideviceId: '', idevicePair: '', afcClient: ''),
          missingTools: ['idevice_id'],
        ),
        runner: _FakeRunner({}),
      );

      final status = await service.detect();

      expect(status.code, IosUsbStatusCode.toolsMissing);
      expect(status.message, contains('idevice_id'));
    });

    test('reports no device when idevice_id has no output', () async {
      final service = IosUsbDeviceService(
        toolResolution: _tools(),
        runner: _FakeRunner({
          'idevice_id.exe -l': const IosUsbCommandResult(exitCode: 0, stdout: '', stderr: '', timedOut: false),
        }),
      );

      final status = await service.detect();

      expect(status.code, IosUsbStatusCode.noDevice);
    });

    test('reports multiple devices when more than one UDID is connected', () async {
      final service = IosUsbDeviceService(
        toolResolution: _tools(),
        runner: _FakeRunner({
          'idevice_id.exe -l': const IosUsbCommandResult(exitCode: 0, stdout: 'a\nb\n', stderr: '', timedOut: false),
        }),
      );

      final status = await service.detect();

      expect(status.code, IosUsbStatusCode.multipleDevices);
      expect(status.message, contains('one iPhone'));
    });

    test('reports trusted device when pair validation succeeds', () async {
      final service = IosUsbDeviceService(
        toolResolution: _tools(),
        runner: _FakeRunner({
          'idevice_id.exe -l': const IosUsbCommandResult(exitCode: 0, stdout: '1234567890abcdef\n', stderr: '', timedOut: false),
          'idevicepair.exe -u 1234567890abcdef validate': const IosUsbCommandResult(
            exitCode: 0,
            stdout: 'SUCCESS: Validated pairing with device\n',
            stderr: '',
            timedOut: false,
          ),
        }),
      );

      final status = await service.detect();

      expect(status.code, IosUsbStatusCode.trusted);
      expect(status.udid, '1234567890abcdef');
      expect(status.displayUdid, '123456...cdef');
    });

    test('reports not trusted when validation asks for trust', () async {
      final service = IosUsbDeviceService(
        toolResolution: _tools(),
        runner: _FakeRunner({
          'idevice_id.exe -l': const IosUsbCommandResult(exitCode: 0, stdout: 'abc\n', stderr: '', timedOut: false),
          'idevicepair.exe -u abc validate': const IosUsbCommandResult(
            exitCode: 255,
            stdout: '',
            stderr: 'ERROR: Please accept the trust dialog on the screen of device abc\n',
            timedOut: false,
          ),
        }),
      );

      final status = await service.detect();

      expect(status.code, IosUsbStatusCode.notTrusted);
      expect(status.message, contains('Trust This Computer'));
    });
  });
}

LibimobiledeviceToolResolution _tools() {
  return const LibimobiledeviceToolResolution(
    tools: LibimobiledeviceTools(
      ideviceId: 'idevice_id.exe',
      idevicePair: 'idevicepair.exe',
      afcClient: 'afcclient.exe',
    ),
    missingTools: [],
  );
}

class _FakeRunner implements IosUsbCommandRunner {
  final Map<String, IosUsbCommandResult> results;

  _FakeRunner(this.results);

  @override
  Future<IosUsbCommandResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    String? stdinText,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final key = [executable, ...arguments].join(' ');
    return results[key] ??
        IosUsbCommandResult(
          exitCode: 99,
          stdout: '',
          stderr: 'Unexpected command: $key',
          timedOut: false,
        );
  }
}
```

- [ ] **Step 2: Run test to verify failure**

Run:

```powershell
dart test test/unit/util/ios_usb_device_test.dart
```

Expected: FAIL because `ios_usb_device.dart` does not exist.

- [ ] **Step 3: Implement device service**

Create `app/lib/util/usb/ios_usb_device.dart` with:

```dart
import 'package:localsend_app/util/usb/ios_usb_command.dart';
import 'package:localsend_app/util/usb/ios_usb_tools.dart';

enum IosUsbStatusCode {
  toolsMissing,
  noDevice,
  multipleDevices,
  notTrusted,
  trusted,
  commandFailed,
}

class IosUsbDeviceStatus {
  final IosUsbStatusCode code;
  final String message;
  final String? udid;

  const IosUsbDeviceStatus({
    required this.code,
    required this.message,
    this.udid,
  });

  String? get displayUdid {
    final value = udid;
    if (value == null) {
      return null;
    }
    if (value.length <= 10) {
      return value;
    }
    return '${value.substring(0, 6)}...${value.substring(value.length - 4)}';
  }
}

class IosUsbDeviceService {
  final LibimobiledeviceToolResolution toolResolution;
  final IosUsbCommandRunner runner;

  const IosUsbDeviceService({
    required this.toolResolution,
    required this.runner,
  });

  Future<IosUsbDeviceStatus> detect() async {
    if (!toolResolution.available) {
      return IosUsbDeviceStatus(
        code: IosUsbStatusCode.toolsMissing,
        message: 'Missing automatic USB tools: ${toolResolution.missingTools.join(', ')}.',
      );
    }

    final listResult = await runner.run(toolResolution.tools.ideviceId, const ['-l']);
    if (!listResult.ok) {
      return IosUsbDeviceStatus(
        code: IosUsbStatusCode.commandFailed,
        message: _driverMessage(listResult),
      );
    }

    final devices = listResult.stdout.split(RegExp(r'\r?\n')).map((line) => line.trim()).where((line) => line.isNotEmpty).toList();
    if (devices.isEmpty) {
      return const IosUsbDeviceStatus(
        code: IosUsbStatusCode.noDevice,
        message: 'No iPhone detected over USB. Connect the iPhone, unlock it, and tap Trust This Computer.',
      );
    }
    if (devices.length > 1) {
      return const IosUsbDeviceStatus(
        code: IosUsbStatusCode.multipleDevices,
        message: 'More than one iPhone is connected. Connect only one iPhone for automatic USB sync.',
      );
    }

    final udid = devices.single;
    final validate = await runner.run(toolResolution.tools.idevicePair, ['-u', udid, 'validate']);
    if (validate.ok && validate.stdout.toLowerCase().contains('success')) {
      return IosUsbDeviceStatus(
        code: IosUsbStatusCode.trusted,
        message: 'iPhone trusted and ready.',
        udid: udid,
      );
    }

    final combined = '${validate.stdout}\n${validate.stderr}'.toLowerCase();
    if (combined.contains('trust') || combined.contains('pair')) {
      return IosUsbDeviceStatus(
        code: IosUsbStatusCode.notTrusted,
        message: 'Unlock the iPhone and tap Trust This Computer, then check trust again.',
        udid: udid,
      );
    }

    return IosUsbDeviceStatus(
      code: IosUsbStatusCode.commandFailed,
      message: 'Could not validate iPhone trust state: ${validate.stderr.trim().isEmpty ? validate.stdout.trim() : validate.stderr.trim()}',
      udid: udid,
    );
  }

  Future<IosUsbDeviceStatus> pair(String udid) async {
    final result = await runner.run(toolResolution.tools.idevicePair, ['-u', udid, 'pair']);
    if (result.ok) {
      return IosUsbDeviceStatus(
        code: IosUsbStatusCode.trusted,
        message: 'Pairing completed. The iPhone is trusted.',
        udid: udid,
      );
    }
    return IosUsbDeviceStatus(
      code: IosUsbStatusCode.notTrusted,
      message: 'Pairing needs iPhone confirmation. Unlock the iPhone and tap Trust This Computer.',
      udid: udid,
    );
  }

  String _driverMessage(IosUsbCommandResult result) {
    final text = '${result.stdout}\n${result.stderr}'.trim();
    if (text.isEmpty) {
      return 'Could not talk to Apple Mobile Device USB driver. Install Apple Devices or iTunes, then reconnect the iPhone.';
    }
    return 'Could not detect iPhone over USB: $text';
  }
}
```

- [ ] **Step 4: Run tests**

Run:

```powershell
dart test test/unit/util/ios_usb_device_test.dart
dart analyze lib/util/usb/ios_usb_device.dart test/unit/util/ios_usb_device_test.dart
```

Expected: tests pass; analyzer reports no issues.

- [ ] **Step 5: Commit**

```powershell
git add app/lib/util/usb/ios_usb_device.dart app/test/unit/util/ios_usb_device_test.dart
git commit -m "feat: detect iphone usb trust state"
```

---

### Task 5: AFC File Sharing Service

**Files:**
- Create: `app/lib/util/usb/ios_usb_file_service.dart`
- Create: `app/test/unit/util/ios_usb_file_service_test.dart`

- [ ] **Step 1: Write failing AFC service tests**

Create `app/test/unit/util/ios_usb_file_service_test.dart`:

```dart
import 'dart:io';

import 'package:localsend_app/util/usb/ios_usb_command.dart';
import 'package:localsend_app/util/usb/ios_usb_constants.dart';
import 'package:localsend_app/util/usb/ios_usb_file_service.dart';
import 'package:localsend_app/util/usb/ios_usb_tools.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('iOS USB file service', () {
    test('builds afcclient commands with documents bundle id and udid', () async {
      final runner = _RecordingRunner(const IosUsbCommandResult(exitCode: 0, stdout: 'a.txt\n', stderr: '', timedOut: false));
      final service = IosUsbFileService(tools: _tools(), runner: runner);

      await service.listRemoteFolder(udid: 'abc', remoteFolder: iosUsbOutboxFolderName);

      expect(runner.calls.single.executable, 'afcclient.exe');
      expect(runner.calls.single.arguments, [
        '--documents',
        iphone2winIosBundleId,
        '-u',
        'abc',
        'ls',
        iosUsbOutboxFolderName,
      ]);
    });

    test('parses remote listing and ignores prompts and blank lines', () async {
      final runner = _RecordingRunner(
        const IosUsbCommandResult(
          exitCode: 0,
          stdout: 'AFC> ls USB-Outbox\nfile one.txt\nphoto.jpg\n\nAFC> quit\n',
          stderr: '',
          timedOut: false,
        ),
      );
      final service = IosUsbFileService(tools: _tools(), runner: runner);

      final files = await service.listRemoteFolder(udid: 'abc', remoteFolder: iosUsbOutboxFolderName);

      expect(files, ['file one.txt', 'photo.jpg']);
    });

    test('pulls every remote outbox file into destination with safe unique names', () async {
      final temp = await Directory.systemTemp.createTemp('ios_usb_file_service_test_');
      addTearDown(() async => temp.delete(recursive: true));
      await File(p.join(temp.path, 'photo.jpg')).writeAsString('existing');
      final runner = _ScriptedRunner([
        const IosUsbCommandResult(exitCode: 0, stdout: 'photo.jpg\n', stderr: '', timedOut: false),
        const IosUsbCommandResult(exitCode: 0, stdout: '', stderr: '', timedOut: false),
      ]);
      final service = IosUsbFileService(tools: _tools(), runner: runner);

      final pulled = await service.pullOutbox(udid: 'abc', destination: temp);

      expect(p.basename(pulled.single), 'photo (2).jpg');
      expect(runner.calls.last.arguments, [
        '--documents',
        iphone2winIosBundleId,
        '-u',
        'abc',
        'get',
        'USB-Outbox/photo.jpg',
        pulled.single,
      ]);
    });

    test('pushes local files to USB-Inbox with sanitized remote names', () async {
      final temp = await Directory.systemTemp.createTemp('ios_usb_file_service_test_');
      addTearDown(() async => temp.delete(recursive: true));
      final localFile = await File(p.join(temp.path, 'a<b>.txt')).writeAsString('hello');
      final runner = _RecordingRunner(const IosUsbCommandResult(exitCode: 0, stdout: '', stderr: '', timedOut: false));
      final service = IosUsbFileService(tools: _tools(), runner: runner);

      await service.pushFiles(udid: 'abc', files: [localFile]);

      expect(runner.calls.single.arguments, [
        '--documents',
        iphone2winIosBundleId,
        '-u',
        'abc',
        'put',
        localFile.path,
        'USB-Inbox/a_b_.txt',
      ]);
    });

    test('maps app document access failures to readable exceptions', () async {
      final runner = _RecordingRunner(const IosUsbCommandResult(exitCode: 1, stdout: '', stderr: 'ApplicationLookupFailed', timedOut: false));
      final service = IosUsbFileService(tools: _tools(), runner: runner);

      expect(
        () => service.listRemoteFolder(udid: 'abc', remoteFolder: iosUsbOutboxFolderName),
        throwsA(isA<IosUsbFileServiceException>().having((e) => e.message, 'message', contains('iphone2win iOS app'))),
      );
    });
  });
}

LibimobiledeviceTools _tools() {
  return const LibimobiledeviceTools(
    ideviceId: 'idevice_id.exe',
    idevicePair: 'idevicepair.exe',
    afcClient: 'afcclient.exe',
  );
}

class _CommandCall {
  final String executable;
  final List<String> arguments;

  const _CommandCall(this.executable, this.arguments);
}

class _RecordingRunner implements IosUsbCommandRunner {
  final IosUsbCommandResult result;
  final calls = <_CommandCall>[];

  _RecordingRunner(this.result);

  @override
  Future<IosUsbCommandResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    String? stdinText,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    calls.add(_CommandCall(executable, List.unmodifiable(arguments)));
    return result;
  }
}

class _ScriptedRunner implements IosUsbCommandRunner {
  final List<IosUsbCommandResult> results;
  final calls = <_CommandCall>[];
  var index = 0;

  _ScriptedRunner(this.results);

  @override
  Future<IosUsbCommandResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    String? stdinText,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    calls.add(_CommandCall(executable, List.unmodifiable(arguments)));
    return results[index++];
  }
}
```

- [ ] **Step 2: Run test to verify failure**

Run:

```powershell
dart test test/unit/util/ios_usb_file_service_test.dart
```

Expected: FAIL because `ios_usb_file_service.dart` does not exist.

- [ ] **Step 3: Implement AFC file service**

Create `app/lib/util/usb/ios_usb_file_service.dart` with:

```dart
import 'dart:io';

import 'package:localsend_app/util/usb/ios_usb_command.dart';
import 'package:localsend_app/util/usb/ios_usb_constants.dart';
import 'package:localsend_app/util/usb/ios_usb_tools.dart';
import 'package:localsend_app/util/usb/usb_file_paths.dart';
import 'package:path/path.dart' as p;

class IosUsbFileServiceException implements Exception {
  final String message;

  const IosUsbFileServiceException(this.message);

  @override
  String toString() => message;
}

class IosUsbFileService {
  final LibimobiledeviceTools tools;
  final IosUsbCommandRunner runner;

  const IosUsbFileService({
    required this.tools,
    required this.runner,
  });

  Future<List<String>> listRemoteFolder({
    required String udid,
    required String remoteFolder,
  }) async {
    final result = await _runAfc(udid, ['ls', remoteFolder]);
    return _parseListing(result.stdout);
  }

  Future<List<String>> pullOutbox({
    required String udid,
    required Directory destination,
  }) async {
    await destination.create(recursive: true);
    final remoteFiles = await listRemoteFolder(udid: udid, remoteFolder: iosUsbOutboxFolderName);
    final pulled = <String>[];
    for (final remoteName in remoteFiles) {
      final localFile = await getAvailableUsbFile(destination, remoteName);
      await _runAfc(udid, [
        'get',
        _remotePath(iosUsbOutboxFolderName, remoteName),
        localFile.path,
      ]);
      pulled.add(localFile.path);
    }
    return pulled;
  }

  Future<void> pushFiles({
    required String udid,
    required List<File> files,
  }) async {
    for (final file in files) {
      final remoteName = _safeRemoteFileName(p.basename(file.path));
      await _runAfc(udid, [
        'put',
        file.path,
        _remotePath(iosUsbInboxFolderName, remoteName),
      ]);
    }
  }

  Future<IosUsbCommandResult> _runAfc(String udid, List<String> command) async {
    final result = await runner.run(
      tools.afcClient,
      [
        '--documents',
        iphone2winIosBundleId,
        '-u',
        udid,
        ...command,
      ],
      timeout: const Duration(minutes: 2),
    );
    if (!result.ok) {
      throw IosUsbFileServiceException(_readableAfcError(result));
    }
    return result;
  }

  List<String> _parseListing(String stdout) {
    return stdout
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .where((line) => !line.startsWith('AFC>'))
        .where((line) => !line.startsWith('ls '))
        .toList(growable: false);
  }

  String _remotePath(String folder, String name) {
    return '$folder/${_safeRemoteFileName(name)}';
  }

  String _safeRemoteFileName(String fileName) {
    var sanitized = p.basename(fileName).replaceAll(RegExp(r'[<>:"|?*\\/]'), '_').trim();
    sanitized = sanitized.replaceFirst(RegExp(r'[ .]+$'), '');
    if (sanitized.isEmpty || sanitized == '.' || sanitized == '..') {
      return 'file';
    }
    final extension = p.extension(sanitized);
    var baseName = p.basenameWithoutExtension(sanitized).replaceFirst(RegExp(r'[ .]+$'), '');
    if (baseName.isEmpty || baseName == '.' || baseName == '..') {
      baseName = 'file';
    }
    final upperBaseName = baseName.toUpperCase();
    final reserved = upperBaseName == 'CON' ||
        upperBaseName == 'PRN' ||
        upperBaseName == 'AUX' ||
        upperBaseName == 'NUL' ||
        RegExp(r'^COM[1-9]$').hasMatch(upperBaseName) ||
        RegExp(r'^LPT[1-9]$').hasMatch(upperBaseName);
    return '${reserved ? '${baseName}_' : baseName}$extension';
  }

  String _readableAfcError(IosUsbCommandResult result) {
    final combined = '${result.stdout}\n${result.stderr}'.trim();
    if (combined.contains('ApplicationLookupFailed') || combined.contains('No such application')) {
      return 'Could not access the iphone2win iOS app documents. Install/open the iPhone app once and make sure File Sharing is enabled.';
    }
    if (result.timedOut) {
      return 'The iPhone USB file operation timed out. Unlock the iPhone and reconnect the cable.';
    }
    if (combined.isEmpty) {
      return 'The iPhone USB file operation failed without details.';
    }
    return 'The iPhone USB file operation failed: $combined';
  }
}
```

- [ ] **Step 4: Run AFC service tests**

Run:

```powershell
dart test test/unit/util/ios_usb_file_service_test.dart
dart analyze lib/util/usb/ios_usb_file_service.dart test/unit/util/ios_usb_file_service_test.dart
```

Expected: tests pass; analyzer reports no issues.

- [ ] **Step 5: Commit**

```powershell
git add app/lib/util/usb/ios_usb_file_service.dart app/test/unit/util/ios_usb_file_service_test.dart
git commit -m "feat: add ios app documents usb file service"
```

---

### Task 6: USB Tab Automatic Mode UI

**Files:**
- Modify: `app/lib/pages/tabs/usb_tab.dart`
- Test: `app/test/unit/ui/automatic_usb_sync_source_test.dart`
- Test: `app/test/unit/ui/usb_mode_preserves_existing_flows_test.dart`

- [ ] **Step 1: Run current source test to confirm UI failure**

Run:

```powershell
dart test test/unit/ui/automatic_usb_sync_source_test.dart
```

Expected: FAIL because `usb_tab.dart` does not contain `Automatic USB`, `Detect iPhone`, `Check trust`, `Pull from iPhone`, and `Push selected files to iPhone`.

- [ ] **Step 2: Modify USB tab imports**

Add these imports to `app/lib/pages/tabs/usb_tab.dart`:

```dart
import 'package:localsend_app/model/cross_file.dart';
import 'package:localsend_app/util/usb/ios_usb_command.dart';
import 'package:localsend_app/util/usb/ios_usb_device.dart';
import 'package:localsend_app/util/usb/ios_usb_file_service.dart';
import 'package:localsend_app/util/usb/ios_usb_tools.dart';
```

- [ ] **Step 3: Add automatic state to `_UsbTabState`**

Add fields:

```dart
bool _automaticWorking = false;
IosUsbDeviceStatus? _iosUsbStatus;
LibimobiledeviceToolResolution? _toolResolution;
String? _automaticUsbResult;
```

- [ ] **Step 4: Add service builders**

Add helper methods inside `_UsbTabState`:

```dart
Future<LibimobiledeviceToolResolution> _resolveIosUsbTools() async {
  final resolution = await const LibimobiledeviceToolResolver().resolve();
  _toolResolution = resolution;
  return resolution;
}

Future<IosUsbDeviceStatus> _detectIphone() async {
  final resolution = await _resolveIosUsbTools();
  final status = await IosUsbDeviceService(
    toolResolution: resolution,
    runner: const ProcessIosUsbCommandRunner(),
  ).detect();
  if (mounted) {
    setState(() {
      _iosUsbStatus = status;
      _automaticUsbResult = status.message;
    });
  }
  return status;
}

Future<void> _runAutomaticUsbAction(Future<void> Function() action) async {
  if (_automaticWorking) {
    return;
  }
  setState(() {
    _automaticWorking = true;
  });
  try {
    await action();
  } catch (error) {
    if (mounted) {
      setState(() {
        _automaticUsbResult = error.toString();
      });
    }
  } finally {
    if (mounted) {
      setState(() {
        _automaticWorking = false;
      });
    }
  }
}
```

- [ ] **Step 5: Add pull and push actions**

Add:

```dart
Future<void> _pullFromIphone() async {
  await _runAutomaticUsbAction(() async {
    final status = await _detectIphone();
    if (status.code != IosUsbStatusCode.trusted || status.udid == null) {
      return;
    }
    final resolution = _toolResolution ?? await _resolveIosUsbTools();
    final destination = await getUsbInboxDirectory();
    final pulled = await IosUsbFileService(
      tools: resolution.tools,
      runner: const ProcessIosUsbCommandRunner(),
    ).pullOutbox(udid: status.udid!, destination: destination);
    if (!mounted) {
      return;
    }
    setState(() {
      _automaticUsbResult = pulled.isEmpty ? 'No files found in iPhone USB-Outbox.' : 'Pulled ${pulled.length} file(s) from iPhone USB-Outbox.';
    });
    await _refreshUsbFolders();
  });
}

Future<void> _pushSelectedFilesToIphone() async {
  await _runAutomaticUsbAction(() async {
    final selected = ref.read(selectedSendingFilesProvider);
    final localFiles = selected.where((file) => file.path != null).map((file) => File(file.path!)).toList();
    if (localFiles.isEmpty) {
      setState(() {
        _automaticUsbResult = 'Select file-path based files in the Send tab before pushing to iPhone.';
      });
      return;
    }
    final status = await _detectIphone();
    if (status.code != IosUsbStatusCode.trusted || status.udid == null) {
      return;
    }
    final resolution = _toolResolution ?? await _resolveIosUsbTools();
    await IosUsbFileService(
      tools: resolution.tools,
      runner: const ProcessIosUsbCommandRunner(),
    ).pushFiles(udid: status.udid!, files: localFiles);
    if (mounted) {
      setState(() {
        _automaticUsbResult = 'Pushed ${localFiles.length} file(s) to iPhone USB-Inbox.';
      });
    }
  });
}
```

- [ ] **Step 6: Add UI section**

Insert this section above the existing manual buttons:

```dart
_AutomaticUsbSection(
  busy: _automaticWorking,
  status: _iosUsbStatus,
  result: _automaticUsbResult,
  onDetect: () => _runAutomaticUsbAction(() async {
    await _detectIphone();
  }),
  onCheckTrust: () => _runAutomaticUsbAction(() async {
    await _detectIphone();
  }),
  onPull: _pullFromIphone,
  onPush: _pushSelectedFilesToIphone,
),
const SizedBox(height: 20),
```

Create the widget in the same file:

```dart
class _AutomaticUsbSection extends StatelessWidget {
  final bool busy;
  final IosUsbDeviceStatus? status;
  final String? result;
  final VoidCallback onDetect;
  final VoidCallback onCheckTrust;
  final VoidCallback onPull;
  final VoidCallback onPush;

  const _AutomaticUsbSection({
    required this.busy,
    required this.status,
    required this.result,
    required this.onDetect,
    required this.onCheckTrust,
    required this.onPull,
    required this.onPush,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Automatic USB', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('Uses local libimobiledevice tools over the USB cable to access only the iphone2win app Documents folder.'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : onDetect,
                  icon: const Icon(Icons.usb),
                  label: const Text('Detect iPhone'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : onCheckTrust,
                  icon: const Icon(Icons.verified_user),
                  label: const Text('Check trust'),
                ),
                ElevatedButton.icon(
                  onPressed: busy ? null : onPull,
                  icon: const Icon(Icons.download),
                  label: const Text('Pull from iPhone'),
                ),
                ElevatedButton.icon(
                  onPressed: busy ? null : onPush,
                  icon: const Icon(Icons.upload),
                  label: const Text('Push selected files to iPhone'),
                ),
              ],
            ),
            if (busy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (status != null) ...[
              const SizedBox(height: 12),
              Text('Device status: ${status!.message}'),
            ],
            if (result != null && result!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(result!),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 7: Run UI source tests**

Run:

```powershell
dart test test/unit/ui/automatic_usb_sync_source_test.dart test/unit/ui/usb_mode_preserves_existing_flows_test.dart test/unit/ui/receive_tab_qr_upload_test.dart test/unit/ui/send_tab_qr_download_test.dart
dart analyze lib/pages/tabs/usb_tab.dart
```

Expected: source tests pass; analyzer reports no issues.

- [ ] **Step 8: Commit**

```powershell
git add app/lib/pages/tabs/usb_tab.dart app/test/unit/ui/automatic_usb_sync_source_test.dart
git commit -m "feat: add automatic usb controls"
```

---

### Task 7: Portable Packaging Script

**Files:**
- Create: `scripts/package_windows_portable.ps1`
- Create: `app/test/unit/ui/portable_packaging_source_test.dart`

- [ ] **Step 1: Write failing packaging source test**

Create `app/test/unit/ui/portable_packaging_source_test.dart`:

```dart
import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('portable packaging source', () {
    test('script includes libimobiledevice tools when present', () {
      final script = File('../scripts/package_windows_portable.ps1').readAsStringSync();

      expect(script, contains('tools\\libimobiledevice'));
      expect(script, contains('iphone2win-portable-files.zip'));
      expect(script, contains('Compress-Archive'));
      expect(script, contains('run_iphone2win.cmd'));
    });

    test('script does not require tools to exist for base packaging', () {
      final script = File('../scripts/package_windows_portable.ps1').readAsStringSync();

      expect(script, contains('if (Test-Path -LiteralPath $LibimobiledeviceTools)'));
      expect(script, contains('Automatic USB tools not found'));
    });
  });
}
```

- [ ] **Step 2: Run test to verify failure**

Run:

```powershell
dart test test/unit/ui/portable_packaging_source_test.dart
```

Expected: FAIL because `scripts/package_windows_portable.ps1` does not exist.

- [ ] **Step 3: Create packaging script**

Create `scripts/package_windows_portable.ps1`:

```powershell
param(
  [string]$Root = (Resolve-Path "$PSScriptRoot\..").Path
)

$ErrorActionPreference = 'Stop'

$App = Join-Path $Root 'app'
$Release = Join-Path $App 'build\windows\x64\runner\Release'
$Dist = Join-Path $Root 'dist'
$Payload = Join-Path $env:TEMP ("iphone2win_payload_{0}" -f ([guid]::NewGuid().ToString('N')))
$LibimobiledeviceTools = Join-Path $Root 'tools\libimobiledevice'
$Zip = Join-Path $Dist 'iphone2win-portable-files.zip'

if (-not (Test-Path -LiteralPath $Release)) {
  throw "Windows release directory not found: $Release"
}

New-Item -ItemType Directory -Path $Dist -Force | Out-Null
New-Item -ItemType Directory -Path $Payload -Force | Out-Null

Copy-Item -Path (Join-Path $Release '*') -Destination $Payload -Recurse -Force

if (Test-Path -LiteralPath $LibimobiledeviceTools) {
  $TargetTools = Join-Path $Payload 'tools\libimobiledevice'
  New-Item -ItemType Directory -Path $TargetTools -Force | Out-Null
  Copy-Item -Path (Join-Path $LibimobiledeviceTools '*') -Destination $TargetTools -Recurse -Force
} else {
  Write-Host 'Automatic USB tools not found at tools\libimobiledevice; packaging manual USB/LAN features only.'
}

$Runner = @'
@echo off
setlocal
set "ZIPFILE=%~dp0iphone2win-portable-files.zip"
set "WORKDIR=%TEMP%\iphone2win-portable-run"
if not exist "%ZIPFILE%" (
  echo Missing portable payload: %ZIPFILE%
  pause
  exit /b 1
)
if not exist "%WORKDIR%" mkdir "%WORKDIR%"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -LiteralPath $env:ZIPFILE -DestinationPath $env:WORKDIR -Force"
if errorlevel 1 (
  echo Failed to extract iphone2win portable payload.
  pause
  exit /b 1
)
start "" "%WORKDIR%\iphone2win.exe"
exit /b 0
'@

Set-Content -LiteralPath (Join-Path $Dist 'run_iphone2win.cmd') -Value $Runner -Encoding ASCII

if (Test-Path -LiteralPath $Zip) {
  Remove-Item -LiteralPath $Zip -Force
}
Compress-Archive -Path (Join-Path $Payload '*') -DestinationPath $Zip -Force
Remove-Item -LiteralPath $Payload -Recurse -Force

Write-Host "Updated $Zip"
Write-Host 'Use the existing IExpress packaging step to create iphone2win-portable.exe from iphone2win-portable-files.zip and run_iphone2win.cmd.'
```

- [ ] **Step 4: Run source test**

Run:

```powershell
dart test test/unit/ui/portable_packaging_source_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add scripts/package_windows_portable.ps1 app/test/unit/ui/portable_packaging_source_test.dart
git commit -m "build: package automatic usb tools when present"
```

---

### Task 8: Verification and Manual USB Checklist

**Files:**
- Modify: `docs/superpowers/specs/2026-07-09-iphone2win-automatic-usb-sync-design.md` only if behavior changed during implementation.

- [ ] **Step 1: Format source**

Run:

```powershell
dart format lib/pages/tabs/usb_tab.dart lib/util/usb/ios_usb_constants.dart lib/util/usb/ios_usb_command.dart lib/util/usb/ios_usb_tools.dart lib/util/usb/ios_usb_device.dart lib/util/usb/ios_usb_file_service.dart test/unit/util/ios_usb_command_test.dart test/unit/util/ios_usb_tools_test.dart test/unit/util/ios_usb_device_test.dart test/unit/util/ios_usb_file_service_test.dart test/unit/ui/automatic_usb_sync_source_test.dart test/unit/ui/portable_packaging_source_test.dart
```

Expected: formatter exits 0.

- [ ] **Step 2: Analyze target source**

Run:

```powershell
dart analyze lib/pages/tabs/usb_tab.dart lib/util/usb/ios_usb_constants.dart lib/util/usb/ios_usb_command.dart lib/util/usb/ios_usb_tools.dart lib/util/usb/ios_usb_device.dart lib/util/usb/ios_usb_file_service.dart test/unit/util/ios_usb_command_test.dart test/unit/util/ios_usb_tools_test.dart test/unit/util/ios_usb_device_test.dart test/unit/util/ios_usb_file_service_test.dart test/unit/ui/automatic_usb_sync_source_test.dart test/unit/ui/portable_packaging_source_test.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Run unit/source tests**

Run:

```powershell
dart test test/unit/util/ios_usb_command_test.dart test/unit/util/ios_usb_tools_test.dart test/unit/util/ios_usb_device_test.dart test/unit/util/ios_usb_file_service_test.dart test/unit/ui/automatic_usb_sync_source_test.dart test/unit/ui/portable_packaging_source_test.dart test/unit/ui/usb_mode_preserves_existing_flows_test.dart test/unit/web test/unit/ui/receive_tab_qr_upload_test.dart test/unit/ui/send_tab_qr_download_test.dart test/unit/ui/branding_name_test.dart test/unit/ui/ios_file_sharing_test.dart
flutter test test/unit/util/usb_cable_exporter_test.dart
```

Expected: all tests pass. `flutter test` is needed for `CrossFile`-dependent exporter tests.

- [ ] **Step 4: Build Windows release**

Run:

```powershell
flutter build windows --release
```

Expected: `app/build/windows/x64/runner/Release/iphone2win.exe` exists.

- [ ] **Step 5: Run packaging script**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ..\scripts\package_windows_portable.ps1
```

Expected:

- `dist/iphone2win-portable-files.zip` exists.
- If `tools/libimobiledevice` exists locally, the zip contains `tools/libimobiledevice`.
- If tools do not exist, script prints `Automatic USB tools not found` and still creates the zip.
- `dist/` remains ignored by git.

- [ ] **Step 6: Check git does not track binaries or tools**

Run:

```powershell
git status --short
git check-ignore -v dist tools/libimobiledevice
git ls-files dist tools/libimobiledevice
```

Expected:

- `git status --short` shows only intended source changes before commit or is clean after commit.
- `git check-ignore` reports `.gitignore` entries for `dist` and `tools/libimobiledevice`.
- `git ls-files dist tools/libimobiledevice` prints nothing.

- [ ] **Step 7: Manual verification checklist**

Run these manually on a Windows machine with bundled tools and Apple Devices/iTunes driver installed:

```text
1. Start iphone2win portable app.
2. Connect one unlocked iPhone by USB.
3. Tap Trust This Computer on iPhone.
4. Open USB tab.
5. Click Detect iPhone; expect trusted/ready status.
6. Put a file in iPhone app Documents/USB-Outbox.
7. Click Pull from iPhone; expect file in Windows USB-Inbox.
8. Select a file in Send tab.
9. Click Push selected files to iPhone; expect file in iPhone app Documents/USB-Inbox.
10. Confirm Receive QR upload, Send QR download, browser text transfer, and manual USB buttons still exist.
```

- [ ] **Step 8: Commit final verification updates**

```powershell
git add app/lib app/test scripts docs .gitignore
git commit -m "feat: add automatic iphone usb sync"
```

---

## Self-Review

- Spec coverage: tool resolver, command runner, device status, AFC Documents access, UI controls, packaging, git ignore, privacy boundary, and manual verification are covered.
- Placeholder scan: no placeholder text or unbounded "add tests" steps remain.
- Type consistency: planned files use `IosUsbCommandRunner`, `LibimobiledeviceToolResolution`, `IosUsbDeviceStatus`, and `IosUsbFileService` consistently across tasks.
- Scope check: iOS bundle id migration is explicitly excluded; the plan uses `org.localsend.localsendApp` as specified.
- Risk isolation: uncertain `afcclient` command syntax is contained in `IosUsbFileService._runAfc` and tests assert the v1 command-mode contract.
