import 'dart:io';

import 'package:localsend_app/util/usb/ios_usb_command.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late ProcessIosUsbCommandRunner runner;
  late String dartExecutable;
  var scriptIndex = 0;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ios_usb_command_test_');
    runner = const ProcessIosUsbCommandRunner();
    dartExecutable = _currentDartExecutable();
    scriptIndex = 0;
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<IosUsbCommandResult> runDartSnippet(
    String source, {
    String? stdinText,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final script = File(p.join(tempDir.path, 'snippet_${scriptIndex++}.dart'));
    await script.writeAsString(source);

    return runner.run(
      dartExecutable,
      [script.path],
      stdinText: stdinText,
      timeout: timeout,
    );
  }

  test('successful command returns exit code 0, stdout, and success', () async {
    final result = await runDartSnippet(
      r'''
import 'dart:io';

void main() {
  stdout.write('ios usb ready');
}
''',
    );

    expect(result.exitCode, 0);
    expect(result.stdoutText, 'ios usb ready');
    expect(result.stderrText, isEmpty);
    expect(result.timedOut, isFalse);
    expect(result.isSuccess, isTrue);
  });

  test('failing command returns nonzero exit code and stderr', () async {
    final result = await runDartSnippet(
      r'''
import 'dart:io';

void main() {
  stderr.write('pairing failed');
  exitCode = 7;
}
''',
    );

    expect(result.exitCode, 7);
    expect(result.stdoutText, isEmpty);
    expect(result.stderrText, 'pairing failed');
    expect(result.timedOut, isFalse);
    expect(result.isSuccess, isFalse);
  });

  test('passes stdinText to the child process', () async {
    final result = await runDartSnippet(
      r'''
import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final input = await stdin.transform(utf8.decoder).join();
  stdout.write('received: $input');
}
''',
      stdinText: 'hello from stdin',
    );

    expect(result.exitCode, 0);
    expect(result.stdoutText, 'received: hello from stdin');
    expect(result.stderrText, isEmpty);
    expect(result.isSuccess, isTrue);
  });

  test('timeout kills command and marks result as timed out', () async {
    final result = await runDartSnippet(
      r'''
import 'dart:async';

Future<void> main() async {
  await Future<void>.delayed(const Duration(seconds: 30));
}
''',
      timeout: const Duration(milliseconds: 250),
    );

    expect(result.timedOut, isTrue);
    expect(result.exitCode, isNonZero);
    expect(result.isSuccess, isFalse);
  });

  test('timeout covers stdin writes to child that does not read stdin', () async {
    final result =
        await runDartSnippet(
          r'''
import 'dart:async';

Future<void> main() async {
  await Future<void>.delayed(const Duration(seconds: 30));
}
''',
          stdinText: 'x' * (8 * 1024 * 1024),
          timeout: const Duration(milliseconds: 250),
        ).timeout(
          const Duration(seconds: 5),
          onTimeout: () => fail('runner did not apply timeout while writing stdin'),
        );

    expect(result.timedOut, isTrue);
    expect(result.exitCode, isNonZero);
    expect(result.isSuccess, isFalse);
  });

  test('child exiting before consuming stdin does not make run throw', () async {
    final result = await runDartSnippet(
      r'''
import 'dart:io';

void main() {
  stdout.write('exiting');
  exit(0);
}
''',
      stdinText: 'unused stdin' * 1024,
    );

    expect(result.exitCode, 0);
    expect(result.stdoutText, 'exiting');
    expect(result.timedOut, isFalse);
    expect(result.isSuccess, isTrue);
  });

  test('captures malformed UTF-8 with replacement characters', () async {
    final result = await runDartSnippet(
      r'''
import 'dart:io';

Future<void> main() async {
  stdout.add([0x66, 0x6f, 0x80, 0x6f]);
  stderr.add([0x65, 0xc3, 0x28]);
  await stdout.flush();
  await stderr.flush();
}
''',
    );

    expect(result.exitCode, 0);
    expect(result.stdoutText, String.fromCharCodes([0x66, 0x6f, 0xfffd, 0x6f]));
    expect(result.stderrText, String.fromCharCodes([0x65, 0xfffd, 0x28]));
    expect(result.isSuccess, isTrue);
  });

  test('captures large stdout and stderr without pipe deadlock', () async {
    final result = await runDartSnippet(
      r'''
import 'dart:io';

Future<void> main() async {
  final stdoutChunk = List<int>.filled(128 * 1024, 0x6f);
  final stderrChunk = List<int>.filled(128 * 1024, 0x65);
  stdout.add(stdoutChunk);
  stderr.add(stderrChunk);
  stdout.add(stdoutChunk);
  stderr.add(stderrChunk);
  await stdout.flush();
  await stderr.flush();
}
''',
    );

    expect(result.exitCode, 0);
    expect(result.stdoutText.length, 256 * 1024);
    expect(result.stderrText.length, 256 * 1024);
    expect(result.stdoutText.codeUnits, everyElement(0x6f));
    expect(result.stderrText.codeUnits, everyElement(0x65));
    expect(result.isSuccess, isTrue);
  });

  test('missing executable returns nonzero result with stderr', () async {
    final missingExecutable = p.join(tempDir.path, 'missing-ios-usb-command-runner.exe');

    final result = await runner.run(missingExecutable, const []);

    expect(result.exitCode, isNonZero);
    expect(result.stdoutText, isEmpty);
    expect(result.stderrText, isNotEmpty);
    expect(result.timedOut, isFalse);
    expect(result.isSuccess, isFalse);
  });
}

String _currentDartExecutable() {
  if (p.basenameWithoutExtension(Platform.resolvedExecutable).toLowerCase() == 'dart') {
    return Platform.resolvedExecutable;
  }

  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? _inferFlutterRootFromResolvedExecutable();
  if (flutterRoot != null) {
    final dartExecutable = p.join(
      flutterRoot,
      'bin',
      'cache',
      'dart-sdk',
      'bin',
      Platform.isWindows ? 'dart.exe' : 'dart',
    );
    if (File(dartExecutable).existsSync()) {
      return dartExecutable;
    }
  }

  fail('Could not find a Dart executable for child process tests. Platform.resolvedExecutable=${Platform.resolvedExecutable}');
}

String? _inferFlutterRootFromResolvedExecutable() {
  final parts = p.split(Platform.resolvedExecutable);
  for (var i = 0; i < parts.length - 1; i++) {
    if (parts[i] == 'bin' && parts[i + 1] == 'cache') {
      return p.joinAll(parts.take(i));
    }
  }
  return null;
}
