import 'dart:io';

import 'package:localsend_app/util/usb/ios_usb_command.dart';
import 'package:localsend_app/util/usb/ios_usb_constants.dart';
import 'package:localsend_app/util/usb/ios_usb_file_service.dart';
import 'package:localsend_app/util/usb/ios_usb_tools.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  const udid = '00008030-001C195E0A10802E';

  late Directory tempDir;
  late _FakeIosUsbCommandRunner runner;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ios_usb_file_service_test_');
    runner = _FakeIosUsbCommandRunner();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  IosUsbFileService service({
    IosUsbResolvedTools? tools,
  }) {
    return IosUsbFileService(
      commandRunner: runner,
      tools: tools ?? _resolvedTools(),
      commandTimeout: const Duration(seconds: 7),
    );
  }

  test('pull lists the app File Sharing outbox with scoped afcclient command', () async {
    runner.queueResult(
      const IosUsbCommandResult(
        exitCode: 0,
        stdoutText: '',
        stderrText: '',
        timedOut: false,
      ),
    );

    final result = await service().pullOutbox(
      udid: udid,
      destination: tempDir,
    );

    expect(result.count, 0);
    expect(runner.calls, hasLength(1));
    expect(runner.calls.single.executable, _afcClientPath);
    expect(runner.calls.single.arguments, [
      '--documents',
      iphone2winIosBundleId,
      '-u',
      udid,
    ]);
    expect(runner.calls.single.stdinText, contains('ls "USB-Outbox"'));
    expect(runner.calls.single.timeout, const Duration(seconds: 7));
  });

  test('pull parses listed remote files into collision-safe local paths', () async {
    await File(p.join(tempDir.path, 'report.txt')).writeAsString('existing');
    runner
      ..queueResult(
        const IosUsbCommandResult(
          exitCode: 0,
          stdoutText: 'afc> ls "USB-Outbox"\nreport.txt\nphoto.jpg\nafc> ',
          stderrText: '',
          timedOut: false,
        ),
      )
      ..queueHandler((call) async {
        await _writeDownloadedFiles(call, {
          'report (2).txt': 'downloaded report',
          'photo.jpg': 'downloaded photo',
        });
        return _successResult;
      });

    final result = await service().pullOutbox(
      udid: udid,
      destination: tempDir,
    );

    expect(result.count, 2);
    expect(
      result.pulledFilePaths.map(p.basename),
      ['report (2).txt', 'photo.jpg'],
    );
    expect(await File(p.join(tempDir.path, 'report.txt')).readAsString(), 'existing');
    expect(await File(p.join(tempDir.path, 'report (2).txt')).readAsString(), 'downloaded report');
    expect(await File(p.join(tempDir.path, 'photo.jpg')).readAsString(), 'downloaded photo');
    expect(runner.calls.last.stdinText, contains('get "USB-Outbox/report.txt"'));
    expect(runner.calls.last.stdinText, contains('get "USB-Outbox/photo.jpg"'));
  });

  test('pull confines unsafe remote names to sanitized local destination paths', () async {
    runner
      ..queueResult(
        const IosUsbCommandResult(
          exitCode: 0,
          stdoutText: '../evil.txt\n',
          stderrText: '',
          timedOut: false,
        ),
      )
      ..queueHandler((call) async {
        await _writeDownloadedFiles(call, {
          '.._evil.txt': 'safe bytes',
        });
        return _successResult;
      });

    final result = await service().pullOutbox(
      udid: udid,
      destination: tempDir,
    );

    expect(result.count, 1);
    expect(p.basename(result.pulledFilePaths.single), '.._evil.txt');
    expect(p.dirname(p.canonicalize(result.pulledFilePaths.single)), p.canonicalize(tempDir.path));
    expect(await File(result.pulledFilePaths.single).readAsString(), 'safe bytes');
    expect(runner.calls.last.stdinText, isNot(contains('../evil.txt')));
    expect(runner.calls.last.stdinText, contains('get "USB-Outbox/.._evil.txt"'));
  });

  test('push uploads local files to the app File Sharing inbox with safe remote names', () async {
    final report = await File(p.join(tempDir.path, 'report .txt')).writeAsString('report bytes');
    final notes = await File(p.join(tempDir.path, 'notes.txt')).writeAsString('note bytes');
    runner.queueResult(_successResult);

    final result = await service().pushFiles(
      udid: udid,
      filePaths: [report.path, notes.path],
    );

    expect(result.count, 2);
    expect(result.pushedFiles.map((file) => file.remoteName), [
      'report.txt',
      'notes.txt',
    ]);
    expect(runner.calls, hasLength(1));
    expect(runner.calls.single.executable, _afcClientPath);
    expect(runner.calls.single.arguments, [
      '--documents',
      iphone2winIosBundleId,
      '-u',
      udid,
    ]);
    expect(runner.calls.single.stdinText, contains('mkdir "USB-Inbox"'));
    expect(runner.calls.single.stdinText, contains('put "${_afcQuoteText(report.path)}" "USB-Inbox/report.txt"'));
    expect(runner.calls.single.stdinText, contains('put "${_afcQuoteText(notes.path)}" "USB-Inbox/notes.txt"'));
  });

  test('push fails clearly for non-file paths before running afcclient', () async {
    final directory = await Directory(p.join(tempDir.path, 'not-a-file')).create();

    expect(
      () => service().pushFiles(
        udid: udid,
        filePaths: [directory.path],
      ),
      throwsA(
        isA<IosUsbFileServiceException>().having(
          (error) => error.message,
          'message',
          contains('not a file'),
        ),
      ),
    );
    expect(runner.calls, isEmpty);
  });

  test('command failure throws service exception with redacted diagnostics', () async {
    runner.queueResult(
      const IosUsbCommandResult(
        exitCode: 7,
        stdoutText: 'stdout for $udid',
        stderrText: 'failed for $udid',
        timedOut: false,
      ),
    );

    try {
      await service().pullOutbox(
        udid: udid,
        destination: tempDir,
      );
      fail('Expected IosUsbFileServiceException');
    } on IosUsbFileServiceException catch (error) {
      expect(error.message, contains('Failed to list iPhone USB outbox'));
      expect(error.message, contains('failed for [redacted-udid]'));
      expect(error.message, isNot(contains(udid)));
      expect(error.stdoutText, 'stdout for [redacted-udid]');
      expect(error.stderrText, 'failed for [redacted-udid]');
      expect(error.exitCode, 7);
      expect(error.timedOut, isFalse);
    }
  });

  test('missing afcclient path throws clear service exception', () async {
    expect(
      () =>
          service(
            tools: _resolvedTools(missingToolNames: [afcClientToolName]),
          ).pullOutbox(
            udid: udid,
            destination: tempDir,
          ),
      throwsA(
        isA<IosUsbFileServiceException>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('Missing afcclient'),
            contains(libimobiledeviceToolFolder),
          ),
        ),
      ),
    );
    expect(runner.calls, isEmpty);
  });
}

const _afcClientPath = '/resolved/tools/afcclient';
const _ideviceIdPath = '/resolved/tools/idevice_id';
const _idevicePairPath = '/resolved/tools/idevicepair';

const _successResult = IosUsbCommandResult(
  exitCode: 0,
  stdoutText: '',
  stderrText: '',
  timedOut: false,
);

final _toolPaths = {
  ideviceIdToolName: _ideviceIdPath,
  idevicePairToolName: _idevicePairPath,
  afcClientToolName: _afcClientPath,
};

IosUsbResolvedTools _resolvedTools({
  List<String> missingToolNames = const [],
}) {
  return IosUsbResolvedTools([
    for (final toolName in requiredIosUsbToolNames)
      IosUsbToolResolution(
        toolName: toolName,
        fileName: toolName,
        path: missingToolNames.contains(toolName) ? null : _toolPaths[toolName],
        source: missingToolNames.contains(toolName) ? IosUsbToolSource.missing : IosUsbToolSource.bundled,
      ),
  ]);
}

Future<void> _writeDownloadedFiles(
  _RecordedCommandCall call,
  Map<String, String> contentByLocalBaseName,
) async {
  final stdinText = call.stdinText ?? '';
  final getCommand = RegExp(r'^get "([^"]+)" "([^"]+)"$', multiLine: true);
  for (final match in getCommand.allMatches(stdinText)) {
    final localPath = _afcUnquoteText(match.group(2)!);
    final content = contentByLocalBaseName[p.basename(localPath)] ?? 'downloaded';
    await File(localPath).writeAsString(content);
  }
}

String _afcQuoteText(String text) {
  return text.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
}

String _afcUnquoteText(String text) {
  return text.replaceAll(r'\"', '"').replaceAll(r'\\', r'\');
}

class _FakeIosUsbCommandRunner implements IosUsbCommandRunner {
  final calls = <_RecordedCommandCall>[];
  final _handlers = <Future<IosUsbCommandResult> Function(_RecordedCommandCall call)>[];

  void queueResult(IosUsbCommandResult result) {
    _handlers.add((_) async => result);
  }

  void queueHandler(Future<IosUsbCommandResult> Function(_RecordedCommandCall call) handler) {
    _handlers.add(handler);
  }

  @override
  Future<IosUsbCommandResult> run(
    String executable,
    List<String> arguments, {
    String? stdinText,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final call = _RecordedCommandCall(
      executable,
      List.unmodifiable(arguments),
      stdinText: stdinText,
      timeout: timeout,
    );
    calls.add(call);

    if (_handlers.isEmpty) {
      throw StateError('No queued result for $executable $arguments');
    }

    return _handlers.removeAt(0)(call);
  }
}

class _RecordedCommandCall {
  const _RecordedCommandCall(
    this.executable,
    this.arguments, {
    this.stdinText,
    this.timeout = const Duration(seconds: 20),
  });

  final String executable;
  final List<String> arguments;
  final String? stdinText;
  final Duration timeout;
}
