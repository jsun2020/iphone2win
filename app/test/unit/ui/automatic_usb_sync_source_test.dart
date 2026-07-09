import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('automatic USB sync source guards', () {
    test('root gitignore keeps release artifacts and bundled tools untracked', () {
      final gitignore = File('../.gitignore').readAsStringSync();

      expect(gitignore, contains('/dist/'));
      expect(gitignore, contains('/.worktrees/'));
      expect(gitignore, contains('/tools/libimobiledevice/'));
    });

    test('USB tab preserves manual cable mode and guards planned automatic UI copy', () {
      final source = File('lib/pages/tabs/usb_tab.dart').readAsStringSync();

      for (final text in [
        'USB Cable Mode',
        'Open USB folder',
        'Export selected files',
        'USB-Inbox',
        'USB-Outbox',
      ]) {
        expect(source, contains(text), reason: text);
      }

      for (final text in [
        'Automatic USB',
        'Detect iPhone',
        'Check trust',
        'Pull from iPhone',
        'Push selected files to iPhone',
      ]) {
        expect(source, contains(text), reason: text);
      }
    });

    test('iOS USB constants keep the current File Sharing bundle id', () {
      final source = File('lib/util/usb/ios_usb_constants.dart').readAsStringSync();

      expect(source, contains("const iphone2winIosBundleId = 'org.localsend.localsendApp';"));
    });
  });
}
