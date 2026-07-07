import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('QR upload browser assets', () {
    test('are local-only and do not reference remote URLs', () {
      final html = _readAsset('assets/web/upload.html');
      final js = _readAsset('assets/web/upload.js');

      expect(html, isNot(contains(RegExp(r'https?://'))));
      expect(js, isNot(contains(RegExp(r'https?://'))));
    });

    test('HTML only loads the local upload script', () {
      final html = _readAsset('assets/web/upload.html');

      expect(html, contains('src="/upload.js"'));
      expect(html, isNot(contains('<script src="http')));
      expect(html, isNot(contains('<link href="http')));
    });

    test('JavaScript targets existing LocalSend v2 upload endpoints', () {
      final js = _readAsset('assets/web/upload.js');

      expect(js, contains('/api/localsend/v2/prepare-upload'));
      expect(js, contains('/api/localsend/v2/upload'));
      expect(js, contains('fetch('));
      expect(js, contains('pin'));
    });
  });
}

String _readAsset(String path) => File(path).readAsStringSync();
