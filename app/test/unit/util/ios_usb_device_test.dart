import 'package:localsend_app/util/usb/ios_usb_command.dart';
import 'package:localsend_app/util/usb/ios_usb_constants.dart';
import 'package:localsend_app/util/usb/ios_usb_device.dart';
import 'package:localsend_app/util/usb/ios_usb_tools.dart';
import 'package:test/test.dart';

void main() {
  test('missing tools returns toolsMissing with missing tool details', () async {
    final runner = _FakeIosUsbCommandRunner();
    final detector = IosUsbDeviceDetector(
      commandRunner: runner,
      tools: _resolvedTools(missingToolNames: [idevicePairToolName]),
    );

    final status = await detector.detect();

    expect(status.code, IosUsbStatusCode.toolsMissing);
    expect(status.udid, isNull);
    expect(status.canTransfer, isFalse);
    expect(status.message, contains(idevicePairToolName));
    expect(status.message, contains(libimobiledeviceToolFolder));
    expect(runner.calls, isEmpty);
  });

  test('empty idevice_id output returns noDevice', () async {
    final runner = _FakeIosUsbCommandRunner()
      ..queueResult(
        const IosUsbCommandResult(
          exitCode: 0,
          stdoutText: '  \r\n\n',
          stderrText: '',
          timedOut: false,
        ),
      );
    final detector = IosUsbDeviceDetector(
      commandRunner: runner,
      tools: _resolvedTools(),
    );

    final status = await detector.detect();

    expect(status.code, IosUsbStatusCode.noDevice);
    expect(status.udid, isNull);
    expect(status.canTransfer, isFalse);
    expect(runner.calls, [
      const _RecordedCommandCall(_ideviceIdPath, ['-l']),
    ]);
  });

  test('nonzero empty idevice_id output returns commandFailed', () async {
    final runner = _FakeIosUsbCommandRunner()
      ..queueResult(
        const IosUsbCommandResult(
          exitCode: 2,
          stdoutText: '',
          stderrText: '',
          timedOut: false,
        ),
      );
    final detector = IosUsbDeviceDetector(
      commandRunner: runner,
      tools: _resolvedTools(),
    );

    final status = await detector.detect();

    expect(status.code, IosUsbStatusCode.commandFailed);
    expect(status.udid, isNull);
    expect(status.canTransfer, isFalse);
    expect(status.message, contains('exit code 2'));
    expect(status.exitCode, 2);
    expect(runner.calls, [
      const _RecordedCommandCall(_ideviceIdPath, ['-l']),
    ]);
  });

  test('timed out empty idevice_id output returns commandFailed', () async {
    final runner = _FakeIosUsbCommandRunner()
      ..queueResult(
        const IosUsbCommandResult(
          exitCode: -1,
          stdoutText: '',
          stderrText: '',
          timedOut: true,
        ),
      );
    final detector = IosUsbDeviceDetector(
      commandRunner: runner,
      tools: _resolvedTools(),
    );

    final status = await detector.detect();

    expect(status.code, IosUsbStatusCode.commandFailed);
    expect(status.udid, isNull);
    expect(status.canTransfer, isFalse);
    expect(status.message, contains('timed out'));
    expect(status.exitCode, -1);
    expect(status.timedOut, isTrue);
    expect(runner.calls, [
      const _RecordedCommandCall(_ideviceIdPath, ['-l']),
    ]);
  });

  test('timed out idevice_id output with no-device text returns commandFailed', () async {
    final runner = _FakeIosUsbCommandRunner()
      ..queueResult(
        const IosUsbCommandResult(
          exitCode: -1,
          stdoutText: '',
          stderrText: 'No device found before timeout.',
          timedOut: true,
        ),
      );
    final detector = IosUsbDeviceDetector(
      commandRunner: runner,
      tools: _resolvedTools(),
    );

    final status = await detector.detect();

    expect(status.code, IosUsbStatusCode.commandFailed);
    expect(status.udid, isNull);
    expect(status.canTransfer, isFalse);
    expect(status.message, contains('timed out'));
    expect(status.stderrText, 'No device found before timeout.');
    expect(status.timedOut, isTrue);
    expect(runner.calls, [
      const _RecordedCommandCall(_ideviceIdPath, ['-l']),
    ]);
  });

  test('passes commandTimeout to runner', () async {
    const commandTimeout = Duration(seconds: 7);
    final runner = _FakeIosUsbCommandRunner()
      ..queueResult(
        const IosUsbCommandResult(
          exitCode: 0,
          stdoutText: '',
          stderrText: '',
          timedOut: false,
        ),
      );
    final detector = IosUsbDeviceDetector(
      commandRunner: runner,
      tools: _resolvedTools(),
      commandTimeout: commandTimeout,
    );

    await detector.detect();

    expect(runner.calls, [
      const _RecordedCommandCall(
        _ideviceIdPath,
        ['-l'],
        timeout: commandTimeout,
      ),
    ]);
  });

  test('single UDID and successful pair validation returns trusted', () async {
    const udid = '00008030-001C195E0A10802E';
    final runner = _FakeIosUsbCommandRunner()
      ..queueResult(
        const IosUsbCommandResult(
          exitCode: 0,
          stdoutText: '  $udid  \n\n',
          stderrText: '',
          timedOut: false,
        ),
      )
      ..queueResult(
        const IosUsbCommandResult(
          exitCode: 0,
          stdoutText: 'SUCCESS: Validated pairing with device.',
          stderrText: '',
          timedOut: false,
        ),
      );
    final detector = IosUsbDeviceDetector(
      commandRunner: runner,
      tools: _resolvedTools(),
    );

    final status = await detector.detect();

    expect(status.code, IosUsbStatusCode.trusted);
    expect(status.udid, udid);
    expect(status.canTransfer, isTrue);
    expect(runner.calls, [
      const _RecordedCommandCall(_ideviceIdPath, ['-l']),
      const _RecordedCommandCall(_idevicePairPath, ['-u', udid, 'validate']),
    ]);
  });

  test('multiple UDIDs returns multipleDevices without pair validation', () async {
    final runner = _FakeIosUsbCommandRunner()
      ..queueResult(
        const IosUsbCommandResult(
          exitCode: 0,
          stdoutText: 'udid-one\n\nudid-two\n',
          stderrText: '',
          timedOut: false,
        ),
      );
    final detector = IosUsbDeviceDetector(
      commandRunner: runner,
      tools: _resolvedTools(),
    );

    final status = await detector.detect();

    expect(status.code, IosUsbStatusCode.multipleDevices);
    expect(status.udid, isNull);
    expect(status.canTransfer, isFalse);
    expect(status.message, contains('one iPhone'));
    expect(runner.calls, [
      const _RecordedCommandCall(_ideviceIdPath, ['-l']),
    ]);
  });

  test('pair validation command failure redacts selected UDID diagnostics', () async {
    const udid = '00008030-001C195E0A10802E';
    final runner = _FakeIosUsbCommandRunner()
      ..queueResult(
        const IosUsbCommandResult(
          exitCode: 0,
          stdoutText: '$udid\n',
          stderrText: '',
          timedOut: false,
        ),
      )
      ..queueResult(
        const IosUsbCommandResult(
          exitCode: 3,
          stdoutText: 'validation started for $udid',
          stderrText: 'unexpected validation failure for $udid',
          timedOut: false,
        ),
      );
    final detector = IosUsbDeviceDetector(
      commandRunner: runner,
      tools: _resolvedTools(),
    );

    final status = await detector.detect();

    expect(status.code, IosUsbStatusCode.commandFailed);
    expect(status.udid, udid);
    expect(status.message, isNot(contains(udid)));
    expect(status.stdoutText, isNot(contains(udid)));
    expect(status.stderrText, isNot(contains(udid)));
    expect(status.message, contains('[redacted-udid]'));
    expect(status.stdoutText, contains('[redacted-udid]'));
    expect(status.stderrText, contains('[redacted-udid]'));
  });

  test('pair validation trust error returns notTrusted', () async {
    const udid = '00008030-001C195E0A10802E';
    final runner = _FakeIosUsbCommandRunner()
      ..queueResult(
        const IosUsbCommandResult(
          exitCode: 0,
          stdoutText: '$udid\n',
          stderrText: '',
          timedOut: false,
        ),
      )
      ..queueResult(
        const IosUsbCommandResult(
          exitCode: 1,
          stdoutText: '',
          stderrText: 'ERROR: Device is not paired with this host.',
          timedOut: false,
        ),
      );
    final detector = IosUsbDeviceDetector(
      commandRunner: runner,
      tools: _resolvedTools(),
    );

    final status = await detector.detect();

    expect(status.code, IosUsbStatusCode.notTrusted);
    expect(status.udid, udid);
    expect(status.canTransfer, isFalse);
    expect(status.message, contains('unlock iPhone'));
    expect(status.message, contains('Trust This Computer'));
    expect(status.stderrText, contains('not paired'));
    expect(runner.calls, [
      const _RecordedCommandCall(_ideviceIdPath, ['-l']),
      const _RecordedCommandCall(_idevicePairPath, ['-u', udid, 'validate']),
    ]);
  });

  test('pair validation trust error in stdout returns notTrusted', () async {
    const udid = '00008030-001C195E0A10802E';
    final runner = _FakeIosUsbCommandRunner()
      ..queueResult(
        const IosUsbCommandResult(
          exitCode: 0,
          stdoutText: '$udid\n',
          stderrText: '',
          timedOut: false,
        ),
      )
      ..queueResult(
        const IosUsbCommandResult(
          exitCode: 1,
          stdoutText: 'Please accept Trust This Computer on the device.',
          stderrText: '',
          timedOut: false,
        ),
      );
    final detector = IosUsbDeviceDetector(
      commandRunner: runner,
      tools: _resolvedTools(),
    );

    final status = await detector.detect();

    expect(status.code, IosUsbStatusCode.notTrusted);
    expect(status.udid, udid);
    expect(status.message, contains('unlock iPhone'));
    expect(status.stdoutText, contains('Trust This Computer'));
  });

  test('pair validation passcode output returns notTrusted', () async {
    const udid = '00008030-001C195E0A10802E';
    final runner = _FakeIosUsbCommandRunner()
      ..queueResult(
        const IosUsbCommandResult(
          exitCode: 0,
          stdoutText: '$udid\n',
          stderrText: '',
          timedOut: false,
        ),
      )
      ..queueResult(
        const IosUsbCommandResult(
          exitCode: 1,
          stdoutText: '',
          stderrText: 'ERROR: passcode is set, enter the passcode on the device.',
          timedOut: false,
        ),
      );
    final detector = IosUsbDeviceDetector(
      commandRunner: runner,
      tools: _resolvedTools(),
    );

    final status = await detector.detect();

    expect(status.code, IosUsbStatusCode.notTrusted);
    expect(status.udid, udid);
    expect(status.message, contains('unlock iPhone'));
    expect(status.stderrText, contains('passcode'));
  });

  test('pair validation timeout without trust signal returns commandFailed', () async {
    const udid = '00008030-001C195E0A10802E';
    final runner = _FakeIosUsbCommandRunner()
      ..queueResult(
        const IosUsbCommandResult(
          exitCode: 0,
          stdoutText: '$udid\n',
          stderrText: '',
          timedOut: false,
        ),
      )
      ..queueResult(
        const IosUsbCommandResult(
          exitCode: -1,
          stdoutText: 'still waiting',
          stderrText: 'validate did not complete',
          timedOut: true,
        ),
      );
    final detector = IosUsbDeviceDetector(
      commandRunner: runner,
      tools: _resolvedTools(),
    );

    final status = await detector.detect();

    expect(status.code, IosUsbStatusCode.commandFailed);
    expect(status.udid, udid);
    expect(status.canTransfer, isFalse);
    expect(status.message, contains('timed out'));
    expect(status.stdoutText, 'still waiting');
    expect(status.stderrText, 'validate did not complete');
    expect(runner.calls, [
      const _RecordedCommandCall(_ideviceIdPath, ['-l']),
      const _RecordedCommandCall(_idevicePairPath, ['-u', udid, 'validate']),
    ]);
  });
}

const _ideviceIdPath = '/resolved/tools/idevice_id';
const _idevicePairPath = '/resolved/tools/idevicepair';
const _afcClientPath = '/resolved/tools/afcclient';

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

class _FakeIosUsbCommandRunner implements IosUsbCommandRunner {
  final calls = <_RecordedCommandCall>[];
  final _results = <IosUsbCommandResult>[];

  void queueResult(IosUsbCommandResult result) {
    _results.add(result);
  }

  @override
  Future<IosUsbCommandResult> run(
    String executable,
    List<String> arguments, {
    String? stdinText,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    calls.add(
      _RecordedCommandCall(
        executable,
        List.unmodifiable(arguments),
        timeout: timeout,
      ),
    );

    if (_results.isEmpty) {
      throw StateError('No queued result for $executable $arguments');
    }

    return _results.removeAt(0);
  }
}

class _RecordedCommandCall {
  const _RecordedCommandCall(
    this.executable,
    this.arguments, {
    this.timeout = const Duration(seconds: 20),
  });

  final String executable;
  final List<String> arguments;
  final Duration timeout;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is _RecordedCommandCall && other.executable == executable && _listEquals(other.arguments, arguments) && other.timeout == timeout;
  }

  @override
  int get hashCode => Object.hash(
    executable,
    Object.hashAll(arguments),
    timeout,
  );

  @override
  String toString() => '_RecordedCommandCall($executable, $arguments, $timeout)';
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (left.length != right.length) {
    return false;
  }

  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) {
      return false;
    }
  }

  return true;
}
