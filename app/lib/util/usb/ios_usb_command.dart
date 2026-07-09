import 'dart:async';
import 'dart:convert';
import 'dart:io';

class IosUsbCommandResult {
  const IosUsbCommandResult({
    required this.exitCode,
    required this.stdoutText,
    required this.stderrText,
    required this.timedOut,
  });

  final int exitCode;
  final String stdoutText;
  final String stderrText;
  final bool timedOut;

  bool get isSuccess => exitCode == 0 && !timedOut;
}

abstract class IosUsbCommandRunner {
  Future<IosUsbCommandResult> run(
    String executable,
    List<String> arguments, {
    String? stdinText,
    Duration timeout = const Duration(seconds: 20),
  });
}

class ProcessIosUsbCommandRunner implements IosUsbCommandRunner {
  const ProcessIosUsbCommandRunner();

  static const _failureExitCode = -1;
  static const _outputDrainTimeout = Duration(seconds: 1);
  static const _utf8Decoder = Utf8Decoder(allowMalformed: true);

  @override
  Future<IosUsbCommandResult> run(
    String executable,
    List<String> arguments, {
    String? stdinText,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final Process process;
    try {
      process = await Process.start(
        executable,
        arguments,
        runInShell: false,
      );
    } catch (error) {
      return IosUsbCommandResult(
        exitCode: _failureExitCode,
        stdoutText: '',
        stderrText: error.toString(),
        timedOut: false,
      );
    }

    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();
    final stdoutDone = process.stdout.transform(_utf8Decoder).forEach(stdoutBuffer.write);
    final stderrDone = process.stderr.transform(_utf8Decoder).forEach(stderrBuffer.write);
    final outputDone = Future.wait([stdoutDone, stderrDone]);

    return _waitForProcess(
      process,
      stdoutBuffer,
      stderrBuffer,
      outputDone,
      stdinText,
    ).timeout(
      timeout,
      onTimeout: () => _killAndReturnTimedOut(
        process,
        stdoutBuffer,
        stderrBuffer,
        outputDone,
      ),
    );
  }

  Future<IosUsbCommandResult> _waitForProcess(
    Process process,
    StringBuffer stdoutBuffer,
    StringBuffer stderrBuffer,
    Future<List<void>> outputDone,
    String? stdinText,
  ) async {
    await _writeAndCloseStdin(process, stdinText);
    final exitCode = await process.exitCode;
    await outputDone;

    return IosUsbCommandResult(
      exitCode: exitCode,
      stdoutText: stdoutBuffer.toString(),
      stderrText: stderrBuffer.toString(),
      timedOut: false,
    );
  }

  Future<IosUsbCommandResult> _killAndReturnTimedOut(
    Process process,
    StringBuffer stdoutBuffer,
    StringBuffer stderrBuffer,
    Future<List<void>> outputDone,
  ) async {
    process.kill();
    unawaited(_closeStdin(process));

    var exitCode = await process.exitCode.timeout(
      _outputDrainTimeout,
      onTimeout: () => _failureExitCode,
    );

    await _waitForOutput(outputDone);

    if (exitCode == 0) {
      exitCode = _failureExitCode;
    }

    return IosUsbCommandResult(
      exitCode: exitCode,
      stdoutText: stdoutBuffer.toString(),
      stderrText: stderrBuffer.toString(),
      timedOut: true,
    );
  }

  Future<void> _writeAndCloseStdin(Process process, String? stdinText) async {
    try {
      if (stdinText != null) {
        process.stdin.write(stdinText);
      }
      await process.stdin.flush();
    } catch (_) {
      // The child process may exit before consuming stdin. Preserve the process result.
    } finally {
      await _closeStdin(process);
    }
  }

  Future<void> _closeStdin(Process process) async {
    try {
      await process.stdin.close();
    } catch (_) {
      // Closing stdin is best-effort once the child process exits or is killed.
    }
  }

  Future<void> _waitForOutput(Future<List<void>> outputDone) async {
    try {
      await outputDone.timeout(_outputDrainTimeout);
    } on TimeoutException {
      // Return the output captured before the timeout instead of hanging.
    }
  }
}
