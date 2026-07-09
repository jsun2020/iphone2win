import 'dart:io';

import 'package:localsend_app/util/usb/ios_usb_constants.dart';
import 'package:path/path.dart' as p;

typedef IosUsbFileExists = bool Function(String path);
typedef IosUsbPathToolPath = String? Function(String toolFileName);

const requiredIosUsbToolNames = [
  ideviceIdToolName,
  idevicePairToolName,
  afcClientToolName,
];

enum IosUsbToolSource {
  bundled,
  path,
  missing,
}

class IosUsbToolResolution {
  const IosUsbToolResolution({
    required this.toolName,
    required this.fileName,
    required this.path,
    required this.source,
  });

  final String toolName;
  final String fileName;
  final String? path;
  final IosUsbToolSource source;

  bool get exists => path != null;
}

class IosUsbResolvedTools {
  IosUsbResolvedTools(Iterable<IosUsbToolResolution> tools)
    : toolsByName = Map.unmodifiable({
        for (final tool in tools) tool.toolName: tool,
      });

  final Map<String, IosUsbToolResolution> toolsByName;

  bool get allRequiredToolsExist {
    return requiredIosUsbToolNames.every(
      (toolName) => toolsByName[toolName]?.exists ?? false,
    );
  }

  List<String> get missingToolNames {
    return [
      for (final toolName in requiredIosUsbToolNames)
        if (!(toolsByName[toolName]?.exists ?? false)) toolName,
    ];
  }

  String? get missingToolsMessage {
    final missing = missingToolNames;
    if (missing.isEmpty) {
      return null;
    }

    return 'Missing iOS USB tools in $libimobiledeviceToolFolder or PATH: '
        '${missing.join(', ')}. Add them to $libimobiledeviceToolFolder or '
        'install libimobiledevice tools on PATH.';
  }

  IosUsbToolResolution resolutionFor(String toolName) {
    final resolution = toolsByName[toolName];
    if (resolution == null) {
      throw ArgumentError.value(
        toolName,
        'toolName',
        'No resolution exists for this tool.',
      );
    }
    return resolution;
  }

  String? pathFor(String toolName) => toolsByName[toolName]?.path;
}

String platformToolFileName(String toolName, {bool? isWindows}) {
  if (isWindows ?? Platform.isWindows) {
    return '$toolName.exe';
  }
  return toolName;
}

IosUsbResolvedTools resolveIosUsbTools({
  String? executableDirectory,
  String? currentDirectory,
  Iterable<String> developmentRootDirectories = const [],
  bool? isWindows,
  IosUsbFileExists fileExists = _defaultFileExists,
  IosUsbPathToolPath pathToolPath = _defaultPathToolPath,
}) {
  final windows = isWindows ?? Platform.isWindows;
  final bundledRoots = _bundledSearchRoots(
    executableDirectory ?? _currentExecutableDirectory(),
    currentDirectory ?? Directory.current.path,
    developmentRootDirectories,
  );

  return IosUsbResolvedTools([
    for (final toolName in requiredIosUsbToolNames)
      _resolveTool(
        toolName,
        isWindows: windows,
        bundledRoots: bundledRoots,
        fileExists: fileExists,
        pathToolPath: pathToolPath,
      ),
  ]);
}

IosUsbToolResolution _resolveTool(
  String toolName, {
  required bool isWindows,
  required List<String> bundledRoots,
  required IosUsbFileExists fileExists,
  required IosUsbPathToolPath pathToolPath,
}) {
  final fileName = platformToolFileName(toolName, isWindows: isWindows);

  for (final root in bundledRoots) {
    final candidate = p.join(root, libimobiledeviceToolFolder, fileName);
    if (fileExists(candidate)) {
      return IosUsbToolResolution(
        toolName: toolName,
        fileName: fileName,
        path: candidate,
        source: IosUsbToolSource.bundled,
      );
    }
  }

  final resolvedPath = pathToolPath(fileName);
  if (resolvedPath != null) {
    return IosUsbToolResolution(
      toolName: toolName,
      fileName: fileName,
      path: resolvedPath,
      source: IosUsbToolSource.path,
    );
  }

  return IosUsbToolResolution(
    toolName: toolName,
    fileName: fileName,
    path: null,
    source: IosUsbToolSource.missing,
  );
}

List<String> _bundledSearchRoots(
  String executableDirectory,
  String currentDirectory,
  Iterable<String> developmentRootDirectories,
) {
  final roots = <String>[];
  final seen = <String>{};

  void addRoot(String root) {
    if (root.isEmpty) {
      return;
    }

    final normalized = p.normalize(root);
    if (seen.add(normalized)) {
      roots.add(normalized);
    }
  }

  addRoot(executableDirectory);
  addRoot(currentDirectory);
  for (final root in _parentDirectories(currentDirectory)) {
    addRoot(root);
  }
  for (final root in developmentRootDirectories) {
    addRoot(root);
  }

  return roots;
}

Iterable<String> _parentDirectories(String directory) sync* {
  var current = p.normalize(directory);

  while (true) {
    final parent = p.dirname(current);
    if (parent == current) {
      return;
    }

    yield parent;
    current = parent;
  }
}

String _currentExecutableDirectory() {
  return File(Platform.resolvedExecutable).parent.path;
}

bool _defaultFileExists(String path) {
  return File(path).existsSync();
}

String? _defaultPathToolPath(String toolFileName) {
  final pathValue = Platform.environment['PATH'] ?? Platform.environment['Path'] ?? Platform.environment['path'];
  if (pathValue == null || pathValue.isEmpty) {
    return null;
  }

  final separator = Platform.isWindows ? ';' : ':';
  for (final entry in pathValue.split(separator)) {
    final directory = entry.trim().replaceAll('"', '');
    if (directory.isEmpty) {
      continue;
    }

    final candidate = p.join(directory, toolFileName);
    if (_defaultFileExists(candidate)) {
      return candidate;
    }
  }

  return null;
}
