import 'dart:convert';

import 'package:localsend_app/util/usb/ios_usb_command.dart';
import 'package:localsend_app/util/usb/ios_usb_constants.dart';
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
  const IosUsbDeviceStatus({
    required this.code,
    required this.message,
    this.udid,
    this.stdoutText,
    this.stderrText,
    this.exitCode,
    this.timedOut = false,
  });

  final IosUsbStatusCode code;
  final String? udid;
  final String message;
  final String? stdoutText;
  final String? stderrText;
  final int? exitCode;
  final bool timedOut;

  bool get canTransfer => code == IosUsbStatusCode.trusted && udid != null;
}

class IosUsbDeviceDetector {
  const IosUsbDeviceDetector({
    required IosUsbCommandRunner commandRunner,
    required IosUsbResolvedTools tools,
    this.commandTimeout = const Duration(seconds: 20),
  }) : _commandRunner = commandRunner,
       _tools = tools;

  final IosUsbCommandRunner _commandRunner;
  final IosUsbResolvedTools _tools;
  final Duration commandTimeout;

  Future<IosUsbDeviceStatus> detect() async {
    final missingToolsMessage = _tools.missingToolsMessage;
    if (missingToolsMessage != null) {
      return IosUsbDeviceStatus(
        code: IosUsbStatusCode.toolsMissing,
        message: missingToolsMessage,
      );
    }

    final listResult = await _commandRunner.run(
      _requiredToolPath(ideviceIdToolName),
      const ['-l'],
      timeout: commandTimeout,
    );
    final udids = _parseUdids(listResult.stdoutText);

    if (udids.isEmpty) {
      if (_isNoDeviceListResult(listResult)) {
        return IosUsbDeviceStatus(
          code: IosUsbStatusCode.noDevice,
          message: 'No iPhone detected. Connect one unlocked iPhone with USB and try again.',
          exitCode: listResult.exitCode,
          timedOut: listResult.timedOut,
        );
      }

      return _commandFailed(
        operation: 'Failed to list connected iPhones',
        result: listResult,
      );
    }

    if (!listResult.isSuccess) {
      return _commandFailed(
        operation: 'Failed to list connected iPhones',
        result: listResult,
        knownUdids: udids,
      );
    }

    if (udids.length > 1) {
      return const IosUsbDeviceStatus(
        code: IosUsbStatusCode.multipleDevices,
        message: 'Multiple iPhones detected. Connect one iPhone over USB and try again.',
      );
    }

    final udid = udids.single;
    final validateResult = await _commandRunner.run(
      _requiredToolPath(idevicePairToolName),
      ['-u', udid, 'validate'],
      timeout: commandTimeout,
    );

    if (validateResult.isSuccess) {
      return IosUsbDeviceStatus(
        code: IosUsbStatusCode.trusted,
        udid: udid,
        message: 'iPhone is trusted and ready for USB transfer.',
        exitCode: validateResult.exitCode,
        timedOut: validateResult.timedOut,
      );
    }

    if (_indicatesTrustRequired(validateResult)) {
      final knownUdids = [udid];

      return IosUsbDeviceStatus(
        code: IosUsbStatusCode.notTrusted,
        udid: udid,
        message: 'Please unlock iPhone and tap Trust This Computer, then try again.',
        stdoutText: _redactKnownUdids(validateResult.stdoutText, knownUdids),
        stderrText: _redactKnownUdids(validateResult.stderrText, knownUdids),
        exitCode: validateResult.exitCode,
        timedOut: validateResult.timedOut,
      );
    }

    return _commandFailed(
      operation: 'Failed to validate iPhone trust status',
      result: validateResult,
      udid: udid,
    );
  }

  String _requiredToolPath(String toolName) {
    final path = _tools.pathFor(toolName);
    if (path == null) {
      throw StateError('Missing resolved path for $toolName.');
    }
    return path;
  }

  IosUsbDeviceStatus _commandFailed({
    required String operation,
    required IosUsbCommandResult result,
    String? udid,
    Iterable<String> knownUdids = const [],
  }) {
    final udidsToRedact = {
      if (udid != null) udid,
      ...knownUdids,
    };

    return IosUsbDeviceStatus(
      code: IosUsbStatusCode.commandFailed,
      udid: udid,
      message: '$operation${result.timedOut ? ' (timed out)' : ''}: ${_commandDetails(result, udidsToRedact)}',
      stdoutText: _redactKnownUdids(result.stdoutText, udidsToRedact),
      stderrText: _redactKnownUdids(result.stderrText, udidsToRedact),
      exitCode: result.exitCode,
      timedOut: result.timedOut,
    );
  }
}

List<String> _parseUdids(String stdoutText) {
  return [
    for (final line in const LineSplitter().convert(stdoutText))
      if (line.trim().isNotEmpty) line.trim(),
  ];
}

bool _isNoDeviceListResult(IosUsbCommandResult result) {
  if (result.timedOut) {
    return false;
  }

  return result.isSuccess || _outputIndicatesNoDevice(result);
}

bool _outputIndicatesNoDevice(IosUsbCommandResult result) {
  final output = '${result.stdoutText}\n${result.stderrText}'.toLowerCase();
  return output.contains('no device') ||
      output.contains('no devices') ||
      output.contains('device not found') ||
      output.contains('could not find device') ||
      output.contains('unable to discover device');
}

bool _indicatesTrustRequired(IosUsbCommandResult result) {
  final output = '${result.stdoutText}\n${result.stderrText}'.toLowerCase();
  return output.contains('trust this computer') ||
      output.contains('not trusted') ||
      output.contains('trust dialog') ||
      output.contains('please accept trust') ||
      output.contains('invalid host pairing') ||
      output.contains('host pairing') ||
      output.contains('invalid hostid') ||
      output.contains('invalid host id') ||
      output.contains('lockdownd_invalid_host_id') ||
      output.contains('device is not paired') ||
      output.contains('not paired with this host') ||
      output.contains('please pair') ||
      output.contains('passcode') ||
      output.contains('device is locked') ||
      output.contains('device locked') ||
      output.contains('locked device') ||
      output.contains('unlock the device') ||
      output.contains('unlock device') ||
      output.contains('unlock your device');
}

String _commandDetails(
  IosUsbCommandResult result,
  Iterable<String> knownUdids,
) {
  final stderr = _redactKnownUdids(result.stderrText.trim(), knownUdids);
  if (stderr.isNotEmpty) {
    return stderr;
  }

  final stdout = _redactKnownUdids(result.stdoutText.trim(), knownUdids);
  if (stdout.isNotEmpty) {
    return stdout;
  }

  return 'exit code ${result.exitCode}';
}

String _redactKnownUdids(String text, Iterable<String> knownUdids) {
  var redacted = text;

  for (final udid in knownUdids.where((udid) => udid.isNotEmpty).toSet()) {
    redacted = redacted.replaceAll(udid, '[redacted-udid]');
  }

  return redacted;
}
