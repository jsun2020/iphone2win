import 'dart:io';

import 'package:localsend_app/util/usb/usb_file_paths.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late String source;
  late Directory tempDir;

  setUp(() async {
    source = await File('lib/util/usb/usb_cable_paths.dart').readAsString();
    tempDir = await Directory.systemTemp.createTemp('usb_cable_paths_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('uses stable folder names', () {
    expect(usbInboxFolderName, 'USB-Inbox');
    expect(usbOutboxFolderName, 'USB-Outbox');
    expect(usbWindowsStagingFolderName, 'iphone2win USB');
  });

  test('returns collision-safe filenames', () async {
    await File(p.join(tempDir.path, 'report.txt')).create();
    await File(p.join(tempDir.path, 'report (2).txt')).create();

    final file = await getAvailableUsbFile(tempDir, 'report.txt');

    expect(p.basename(file.path), 'report (3).txt');
    expect(p.dirname(file.path), tempDir.path);
  });

  test('sanitizes path separators in filenames', () async {
    final file = await getAvailableUsbFile(tempDir, r'folder\report/name.txt');

    expect(p.basename(file.path), 'folder_report_name.txt');
    expect(p.dirname(file.path), tempDir.path);
  });

  test('sanitizes Windows-unsafe basenames', () async {
    final cases = {
      '.': 'file',
      '..': 'file',
      '   ': 'file',
      'a<b>c:d"e|f?g*.txt': 'a_b_c_d_e_f_g_.txt',
      'CON': 'CON_',
      'prn.txt': 'prn_.txt',
      'AUX': 'AUX_',
      'nul.log': 'nul_.log',
      'COM1': 'COM1_',
      'com9.txt': 'com9_.txt',
      'LPT1': 'LPT1_',
      'lpt9.txt': 'lpt9_.txt',
      'report .txt': 'report.txt',
      'report...': 'report',
    };

    for (final entry in cases.entries) {
      final file = await getAvailableUsbFile(tempDir, entry.key);
      expect(p.basename(file.path), entry.value, reason: entry.key);
      expect(p.dirname(file.path), tempDir.path, reason: entry.key);
    }
  });

  test('returns collision-safe filenames after sanitization', () async {
    await File(p.join(tempDir.path, 'a_b_.txt')).create();

    final file = await getAvailableUsbFile(tempDir, 'a<b>.txt');

    expect(p.basename(file.path), 'a_b_ (2).txt');
    expect(p.dirname(file.path), tempDir.path);
  });

  test('uses Flutter application documents provider for iOS root', () {
    expect(source, contains("import 'package:flutter/foundation.dart'"));
    expect(source, contains("import 'package:path_provider/path_provider.dart' as path_provider"));
    expect(source, contains('defaultTargetPlatform == TargetPlatform.iOS'));
    expect(source, contains('path_provider.getApplicationDocumentsDirectory()'));

    final iosBranch = RegExp(
      r'if \(defaultTargetPlatform == TargetPlatform\.iOS\) \{(?<body>[\s\S]*?)\n  \}',
    ).firstMatch(source)?.namedGroup('body');
    expect(iosBranch, isNotNull);
    expect(iosBranch, isNot(contains("Platform.environment['HOME']")));
  });
}
