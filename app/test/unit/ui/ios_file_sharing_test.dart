import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('iOS file sharing', () {
    test('Runner Info.plist exposes documents to Files and Finder', () {
      final plist = _readProjectFile('ios/Runner/Info.plist');

      expect(plist, contains('<key>UIFileSharingEnabled</key>'));
      expect(plist, contains('<true/>'));
      expect(plist, contains('<key>LSSupportsOpeningDocumentsInPlace</key>'));
      _expectTrueValueFollowsKey(plist, 'UIFileSharingEnabled');
      _expectTrueValueFollowsKey(plist, 'LSSupportsOpeningDocumentsInPlace');
    });
  });
}

String _readProjectFile(String path) {
  return File(path).readAsStringSync();
}

void _expectTrueValueFollowsKey(String plist, String key) {
  expect(
    plist,
    matches(RegExp('<key>${RegExp.escape(key)}</key>\\s*<true\\s*/>')),
  );
}
