import 'dart:io';

import 'package:localsend_app/util/usb/ios_usb_constants.dart';
import 'package:localsend_app/util/usb/ios_usb_tools.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ios_usb_tools_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('platformToolFileName appends exe only for Windows', () {
    final currentPlatformExpectation = Platform.isWindows ? '$ideviceIdToolName.exe' : ideviceIdToolName;

    expect(platformToolFileName(ideviceIdToolName), currentPlatformExpectation);
    expect(platformToolFileName(ideviceIdToolName, isWindows: true), 'idevice_id.exe');
    expect(platformToolFileName(ideviceIdToolName, isWindows: false), ideviceIdToolName);
  });

  test('resolves all tools from an explicit bundled directory', () async {
    for (final toolName in requiredIosUsbToolNames) {
      await _createBundledTool(tempDir.path, toolName);
    }

    final result = resolveIosUsbTools(
      executableDirectory: p.join(tempDir.path, 'missing-executable-dir'),
      currentDirectory: tempDir.path,
      developmentRootDirectories: const [],
      isWindows: false,
      pathToolPath: (_) => null,
    );

    expect(result.allRequiredToolsExist, isTrue);
    expect(result.missingToolNames, isEmpty);
    expect(result.missingToolsMessage, isNull);

    for (final toolName in requiredIosUsbToolNames) {
      final resolution = result.resolutionFor(toolName);

      expect(resolution.exists, isTrue);
      expect(resolution.source, IosUsbToolSource.bundled);
      expect(
        resolution.path,
        p.join(tempDir.path, libimobiledeviceToolFolder, toolName),
      );
      expect(result.pathFor(toolName), resolution.path);
    }
  });

  test('reports missing tools clearly', () {
    final result = resolveIosUsbTools(
      executableDirectory: p.join(tempDir.path, 'missing-executable-dir'),
      currentDirectory: p.join(tempDir.path, 'missing-current-dir'),
      developmentRootDirectories: const [],
      isWindows: false,
      fileExists: (_) => false,
      pathToolPath: (toolFileName) {
        if (toolFileName == afcClientToolName) {
          return p.join(tempDir.path, 'path-tools', toolFileName);
        }
        return null;
      },
    );

    expect(result.allRequiredToolsExist, isFalse);
    expect(result.missingToolNames, [ideviceIdToolName, idevicePairToolName]);
    expect(result.missingToolsMessage, contains(libimobiledeviceToolFolder));
    expect(result.missingToolsMessage, contains(ideviceIdToolName));
    expect(result.missingToolsMessage, contains(idevicePairToolName));
    expect(result.missingToolsMessage, isNot(contains(afcClientToolName)));
  });

  test('falls back to resolved PATH tool paths', () {
    final pathTools = {
      for (final toolName in requiredIosUsbToolNames) toolName: p.join(tempDir.path, 'path-tools', toolName),
    };

    final result = resolveIosUsbTools(
      executableDirectory: p.join(tempDir.path, 'missing-executable-dir'),
      currentDirectory: p.join(tempDir.path, 'missing-current-dir'),
      developmentRootDirectories: const [],
      isWindows: false,
      fileExists: (_) => false,
      pathToolPath: (toolFileName) => pathTools[toolFileName],
    );

    expect(result.allRequiredToolsExist, isTrue);

    for (final toolName in requiredIosUsbToolNames) {
      final resolution = result.resolutionFor(toolName);

      expect(resolution.exists, isTrue);
      expect(resolution.source, IosUsbToolSource.path);
      expect(resolution.path, pathTools[toolName]);
    }
  });

  test('executable-directory bundled tools win over current-dir dev-root and PATH', () async {
    final executableRoot = p.join(tempDir.path, 'executable');
    final currentRoot = p.join(tempDir.path, 'current');
    final devRoot = p.join(tempDir.path, 'repo');

    await _createAllBundledTools(executableRoot);
    await _createAllBundledTools(currentRoot);
    await _createAllBundledTools(devRoot);

    final result = resolveIosUsbTools(
      executableDirectory: executableRoot,
      currentDirectory: currentRoot,
      developmentRootDirectories: [devRoot],
      isWindows: false,
      pathToolPath: (toolFileName) => p.join(tempDir.path, 'path-tools', toolFileName),
    );

    expect(_allResolvedPaths(result), _expectedBundledPaths(executableRoot));
  });

  test('current-directory bundled tools win over dev-root and PATH', () async {
    final executableRoot = p.join(tempDir.path, 'executable');
    final currentRoot = p.join(tempDir.path, 'current');
    final devRoot = p.join(tempDir.path, 'repo');

    await _createAllBundledTools(currentRoot);
    await _createAllBundledTools(devRoot);

    final result = resolveIosUsbTools(
      executableDirectory: executableRoot,
      currentDirectory: currentRoot,
      developmentRootDirectories: [devRoot],
      isWindows: false,
      pathToolPath: (toolFileName) => p.join(tempDir.path, 'path-tools', toolFileName),
    );

    expect(_allResolvedPaths(result), _expectedBundledPaths(currentRoot));
  });

  test('development-root bundled tools win over PATH', () async {
    final executableRoot = p.join(tempDir.path, 'executable');
    final currentRoot = p.join(tempDir.path, 'current');
    final devRoot = p.join(tempDir.path, 'repo');

    await _createAllBundledTools(devRoot);

    final result = resolveIosUsbTools(
      executableDirectory: executableRoot,
      currentDirectory: currentRoot,
      developmentRootDirectories: [devRoot],
      isWindows: false,
      pathToolPath: (toolFileName) => p.join(tempDir.path, 'path-tools', toolFileName),
    );

    expect(_allResolvedPaths(result), _expectedBundledPaths(devRoot));
  });

  test('development roots resolve repo-root tools when currentDirectory is app', () async {
    final repoRoot = p.join(tempDir.path, 'repo');
    final appRoot = p.join(repoRoot, 'app');

    await Directory(appRoot).create(recursive: true);
    await _createAllBundledTools(repoRoot);

    final result = resolveIosUsbTools(
      executableDirectory: p.join(tempDir.path, 'executable'),
      currentDirectory: appRoot,
      developmentRootDirectories: [repoRoot],
      isWindows: false,
      pathToolPath: (_) => null,
    );

    expect(_allResolvedPaths(result), _expectedBundledPaths(repoRoot));
  });

  test('parent roots resolve repo-root tools when currentDirectory is app', () async {
    final repoRoot = p.join(tempDir.path, 'repo');
    final appRoot = p.join(repoRoot, 'app');

    await Directory(appRoot).create(recursive: true);
    await _createAllBundledTools(repoRoot);

    final result = resolveIosUsbTools(
      executableDirectory: p.join(tempDir.path, 'executable'),
      currentDirectory: appRoot,
      isWindows: false,
      pathToolPath: (_) => p.join(tempDir.path, 'path-tools', 'unused'),
    );

    expect(_allResolvedPaths(result), _expectedBundledPaths(repoRoot));
  });

  test('Windows PATH fallback requests exe filenames and returns resolved paths', () {
    final requestedToolFileNames = <String>[];
    final pathTools = {
      for (final toolName in requiredIosUsbToolNames) '$toolName.exe': p.join(tempDir.path, 'path-tools', '$toolName.exe'),
    };

    final result = resolveIosUsbTools(
      executableDirectory: p.join(tempDir.path, 'missing-executable-dir'),
      currentDirectory: p.join(tempDir.path, 'missing-current-dir'),
      developmentRootDirectories: const [],
      isWindows: true,
      fileExists: (_) => false,
      pathToolPath: (toolFileName) {
        requestedToolFileNames.add(toolFileName);
        return pathTools[toolFileName];
      },
    );

    expect(result.allRequiredToolsExist, isTrue);
    expect(requestedToolFileNames, [
      'idevice_id.exe',
      'idevicepair.exe',
      'afcclient.exe',
    ]);

    for (final toolName in requiredIosUsbToolNames) {
      final resolution = result.resolutionFor(toolName);

      expect(resolution.fileName, '$toolName.exe');
      expect(resolution.source, IosUsbToolSource.path);
      expect(resolution.path, pathTools['$toolName.exe']);
    }
  });
}

Future<void> _createAllBundledTools(String rootDirectory) async {
  for (final toolName in requiredIosUsbToolNames) {
    await _createBundledTool(rootDirectory, toolName);
  }
}

Future<void> _createBundledTool(String rootDirectory, String toolName) async {
  final path = p.join(
    rootDirectory,
    libimobiledeviceToolFolder,
    platformToolFileName(toolName, isWindows: false),
  );

  await File(path).create(recursive: true);
}

Map<String, String?> _allResolvedPaths(IosUsbResolvedTools result) {
  return {
    for (final toolName in requiredIosUsbToolNames) toolName: result.pathFor(toolName),
  };
}

Map<String, String> _expectedBundledPaths(String rootDirectory) {
  return {
    for (final toolName in requiredIosUsbToolNames) toolName: p.join(rootDirectory, libimobiledeviceToolFolder, toolName),
  };
}
