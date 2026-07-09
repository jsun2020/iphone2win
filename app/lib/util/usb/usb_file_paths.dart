import 'dart:io';

import 'package:path/path.dart' as p;

const usbInboxFolderName = 'USB-Inbox';
const usbOutboxFolderName = 'USB-Outbox';
const usbWindowsStagingFolderName = 'iphone2win USB';

Future<File> getAvailableUsbFile(Directory directory, String fileName) async {
  final sanitizedFileName = _sanitizeUsbFileName(fileName);
  final extension = p.extension(sanitizedFileName);
  final baseName = p.basenameWithoutExtension(sanitizedFileName);

  var candidateName = sanitizedFileName;
  var counter = 2;
  var candidatePath = p.join(directory.path, candidateName);
  while (await File(candidatePath).exists()) {
    candidateName = '$baseName ($counter)$extension';
    candidatePath = p.join(directory.path, candidateName);
    counter++;
  }

  final resolvedDirectoryPath = p.canonicalize(directory.absolute.path);
  final resolvedCandidatePath = p.canonicalize(File(candidatePath).absolute.path);
  if (!p.equals(resolvedDirectoryPath, p.dirname(resolvedCandidatePath)) && !p.isWithin(resolvedDirectoryPath, resolvedCandidatePath)) {
    throw ArgumentError.value(fileName, 'fileName', 'Resolved path must stay within the USB directory.');
  }

  return File(candidatePath);
}

String _sanitizeUsbFileName(String fileName) {
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
