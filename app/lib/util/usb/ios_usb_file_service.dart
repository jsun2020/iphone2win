import 'dart:convert';
import 'dart:io';

import 'package:localsend_app/util/usb/ios_usb_command.dart';
import 'package:localsend_app/util/usb/ios_usb_constants.dart';
import 'package:localsend_app/util/usb/ios_usb_tools.dart';
import 'package:localsend_app/util/usb/usb_file_paths.dart';
import 'package:path/path.dart' as p;

class IosUsbFileServiceException implements Exception {
  const IosUsbFileServiceException(
    this.message, {
    this.stdoutText,
    this.stderrText,
    this.exitCode,
    this.timedOut = false,
  });

  final String message;
  final String? stdoutText;
  final String? stderrText;
  final int? exitCode;
  final bool timedOut;

  @override
  String toString() => 'IosUsbFileServiceException: $message';
}

class IosUsbPullResult {
  const IosUsbPullResult({
    required this.pulledFilePaths,
  });

  final List<String> pulledFilePaths;

  int get count => pulledFilePaths.length;
}

class IosUsbPushedFile {
  const IosUsbPushedFile({
    required this.localPath,
    required this.remoteName,
  });

  final String localPath;
  final String remoteName;
}

class IosUsbPushResult {
  const IosUsbPushResult({
    required this.pushedFiles,
  });

  final List<IosUsbPushedFile> pushedFiles;

  int get count => pushedFiles.length;
}

class IosUsbFileService {
  const IosUsbFileService({
    required IosUsbCommandRunner commandRunner,
    required IosUsbResolvedTools tools,
    this.commandTimeout = const Duration(seconds: 60),
  }) : _commandRunner = commandRunner,
       _tools = tools;

  final IosUsbCommandRunner _commandRunner;
  final IosUsbResolvedTools _tools;
  final Duration commandTimeout;

  Future<IosUsbPullResult> pullOutbox({
    required String udid,
    required Directory destination,
  }) async {
    await destination.create(recursive: true);
    await _ensureRemoteFolder(
      udid: udid,
      folderName: iosUsbOutboxFolderName,
    );

    final remoteNames = await _listRemoteFiles(
      udid: udid,
      folderName: iosUsbOutboxFolderName,
    );
    if (remoteNames.isEmpty) {
      return const IosUsbPullResult(pulledFilePaths: []);
    }

    final pulledFilePaths = <String>[];
    final reservedLocalPaths = <String>{};
    final script = StringBuffer();
    for (final remoteName in remoteNames) {
      final localFile = await _getAvailableUsbFileWithReservations(
        destination,
        remoteName,
        reservedLocalPaths,
      );
      final safeRemoteName = _safeRemoteFileName(remoteName);
      script.writeln(
        'get ${_quoteAfcArgument(_remotePath(iosUsbOutboxFolderName, safeRemoteName))} '
        '${_quoteAfcArgument(localFile.path)}',
      );
      pulledFilePaths.add(localFile.path);
    }
    script.writeln('quit');

    await _runAfc(
      udid: udid,
      stdinText: script.toString(),
      operation: 'Failed to pull iPhone USB outbox files',
    );

    return IosUsbPullResult(
      pulledFilePaths: List.unmodifiable(pulledFilePaths),
    );
  }

  Future<IosUsbPushResult> pushFiles({
    required String udid,
    required Iterable<String> filePaths,
  }) async {
    final pushedFiles = <IosUsbPushedFile>[];
    for (final filePath in filePaths) {
      final file = File(filePath);
      final stat = await file.stat();
      if (stat.type != FileSystemEntityType.file) {
        throw const IosUsbFileServiceException(
          'Selected USB upload path is not a file.',
        );
      }

      pushedFiles.add(
        IosUsbPushedFile(
          localPath: file.path,
          remoteName: _safeRemoteFileName(p.basename(file.path)),
        ),
      );
    }

    if (pushedFiles.isEmpty) {
      return const IosUsbPushResult(pushedFiles: []);
    }

    await _ensureRemoteFolder(
      udid: udid,
      folderName: iosUsbInboxFolderName,
    );

    final script = StringBuffer();
    for (final pushedFile in pushedFiles) {
      script.writeln(
        'put ${_quoteAfcArgument(pushedFile.localPath)} '
        '${_quoteAfcArgument(_remotePath(iosUsbInboxFolderName, pushedFile.remoteName))}',
      );
    }
    script.writeln('quit');

    await _runAfc(
      udid: udid,
      stdinText: script.toString(),
      operation: 'Failed to push files to iPhone USB inbox',
    );

    return IosUsbPushResult(
      pushedFiles: List.unmodifiable(pushedFiles),
    );
  }

  Future<List<String>> _listRemoteFiles({
    required String udid,
    required String folderName,
  }) async {
    final result = await _runAfc(
      udid: udid,
      stdinText: 'ls ${_quoteAfcArgument(folderName)}\nquit\n',
      operation: 'Failed to list iPhone USB outbox',
    );

    return _parseAfcListOutput(result.stdoutText);
  }

  Future<void> _ensureRemoteFolder({
    required String udid,
    required String folderName,
  }) async {
    await _runAfc(
      udid: udid,
      stdinText: 'mkdir ${_quoteAfcArgument(folderName)}\nquit\n',
      operation: 'Failed to prepare iPhone USB folder',
      ignoreCommandErrors: true,
    );
  }

  Future<IosUsbCommandResult> _runAfc({
    required String udid,
    required String stdinText,
    required String operation,
    bool ignoreCommandErrors = false,
  }) async {
    final afcClientPath = _afcClientPath();
    final result = await _commandRunner.run(
      afcClientPath,
      ['--documents', iphone2winIosBundleId, '-u', udid],
      stdinText: stdinText,
      timeout: commandTimeout,
    );

    if (!result.isSuccess || (!ignoreCommandErrors && _containsAfcCommandError(result))) {
      throw _commandFailure(
        operation: operation,
        result: result,
        udid: udid,
      );
    }

    return result;
  }

  String _afcClientPath() {
    final path = _tools.pathFor(afcClientToolName);
    if (path == null) {
      throw const IosUsbFileServiceException(
        'Missing afcclient tool. Add it to tools/libimobiledevice or install libimobiledevice tools on PATH.',
      );
    }
    return path;
  }
}

bool _containsAfcCommandError(IosUsbCommandResult result) {
  final output = '${result.stdoutText}\n${result.stderrText}';
  for (final rawLine in const LineSplitter().convert(output)) {
    var line = rawLine.trim();
    final promptIndex = line.indexOf('>');
    if (promptIndex >= 0 && line.substring(0, promptIndex).toLowerCase().contains('afc')) {
      line = line.substring(promptIndex + 1).trim();
    }
    if (line.toLowerCase().startsWith('error:')) {
      return true;
    }
  }
  return false;
}

List<String> _parseAfcListOutput(String stdoutText) {
  final entries = <String>[];

  for (final rawLine in const LineSplitter().convert(stdoutText)) {
    final line = _normalizeAfcListLine(rawLine);
    if (line == null) {
      continue;
    }

    entries.add(line);
  }

  return entries;
}

String? _normalizeAfcListLine(String rawLine) {
  var line = rawLine.trim();
  if (line.isEmpty) {
    return null;
  }

  final promptIndex = line.indexOf('>');
  if (promptIndex >= 0 && line.substring(0, promptIndex).toLowerCase().contains('afc')) {
    line = line.substring(promptIndex + 1).trim();
    if (line.isEmpty) {
      return null;
    }
  }

  final lowerLine = line.toLowerCase();
  if (line == '.' ||
      line == '..' ||
      line == iosUsbOutboxFolderName ||
      line == '$iosUsbOutboxFolderName:' ||
      lowerLine == 'ls' ||
      lowerLine.startsWith('ls ') ||
      lowerLine == 'quit' ||
      lowerLine == 'exit' ||
      lowerLine.startsWith('listing ')) {
    return null;
  }

  return line;
}

Future<File> _getAvailableUsbFileWithReservations(
  Directory directory,
  String fileName,
  Set<String> reservedPaths,
) async {
  final initialFile = await getAvailableUsbFile(directory, fileName);
  final initialName = p.basename(initialFile.path);
  final extension = p.extension(initialName);
  final baseName = p.basenameWithoutExtension(initialName);

  var candidate = initialFile;
  var counter = 2;
  while (reservedPaths.contains(_reservationKey(candidate.path)) || await candidate.exists()) {
    candidate = File(
      p.join(directory.path, '$baseName ($counter)$extension'),
    );
    counter++;
  }

  reservedPaths.add(_reservationKey(candidate.path));
  return candidate;
}

String _reservationKey(String filePath) {
  final canonicalPath = p.canonicalize(File(filePath).absolute.path);
  return Platform.isWindows ? canonicalPath.toLowerCase() : canonicalPath;
}

IosUsbFileServiceException _commandFailure({
  required String operation,
  required IosUsbCommandResult result,
  required String udid,
}) {
  final stdoutText = _sanitizeDiagnostics(result.stdoutText, udid);
  final stderrText = _sanitizeDiagnostics(result.stderrText, udid);
  final details = _commandDetails(
    stdoutText: stdoutText,
    stderrText: stderrText,
    exitCode: result.exitCode,
  );

  return IosUsbFileServiceException(
    '$operation${result.timedOut ? ' (timed out)' : ''}: $details',
    stdoutText: stdoutText,
    stderrText: stderrText,
    exitCode: result.exitCode,
    timedOut: result.timedOut,
  );
}

String _commandDetails({
  required String stdoutText,
  required String stderrText,
  required int exitCode,
}) {
  final stderr = stderrText.trim();
  if (stderr.isNotEmpty) {
    return stderr;
  }

  final stdout = stdoutText.trim();
  if (stdout.isNotEmpty) {
    return stdout;
  }

  return 'exit code $exitCode';
}

String _sanitizeDiagnostics(String text, String udid) {
  var sanitized = text;
  if (udid.isNotEmpty) {
    sanitized = sanitized.replaceAll(udid, '[redacted-udid]');
  }

  sanitized = sanitized.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
  const maxDiagnosticLength = 4000;
  if (sanitized.length > maxDiagnosticLength) {
    sanitized = '${sanitized.substring(0, maxDiagnosticLength)}...';
  }

  return sanitized;
}

String _remotePath(String folderName, String fileName) {
  return p.posix.join(folderName, fileName);
}

String _quoteAfcArgument(String value) {
  return '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
}

String _safeRemoteFileName(String fileName) {
  var sanitized = fileName.replaceAll(RegExp(r'[<>:"|?*\\/]'), '_').trim();
  sanitized = sanitized.replaceFirst(RegExp(r'[ .]+$'), '');

  if (sanitized.isEmpty || sanitized == '.' || sanitized == '..') {
    return 'file';
  }

  final extension = p.extension(sanitized);
  var baseName = p.basenameWithoutExtension(sanitized).replaceFirst(RegExp(r'[ .]+$'), '');
  if (baseName.isEmpty || baseName == '.' || baseName == '..') {
    baseName = 'file';
  }

  if (_isWindowsReservedDeviceName(baseName)) {
    baseName = '${baseName}_';
  }

  return '$baseName$extension';
}

bool _isWindowsReservedDeviceName(String baseName) {
  final upperBaseName = baseName.toUpperCase();
  return upperBaseName == 'CON' ||
      upperBaseName == 'PRN' ||
      upperBaseName == 'AUX' ||
      upperBaseName == 'NUL' ||
      RegExp(r'^COM[1-9]$').hasMatch(upperBaseName) ||
      RegExp(r'^LPT[1-9]$').hasMatch(upperBaseName);
}
