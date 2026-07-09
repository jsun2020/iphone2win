import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('QR text share browser assets', () {
    test('download page JavaScript renders text files with a copy button', () {
      final js = _readAsset('assets/web/main.js');

      expect(js, contains('isTextFile'));
      expect(js, contains('copy-text-button'));
      expect(js, contains('copyTextFromTextarea'));
      expect(js, contains('navigator.clipboard.writeText'));
      expect(js, contains('execCommand'));
    });

    test('download page has styles for text previews', () {
      final html = _readAsset('assets/web/index.html');

      expect(html, contains('.text-item'));
      expect(html, contains('.text-preview'));
      expect(html, contains('.copy-text-button'));
    });

    test('web send embeds the preview from each text file', () {
      final source = _readAsset('lib/provider/network/server/controller/send_controller.dart');

      expect(source, contains('file.fileType == FileType.text'));
      expect(source, isNot(contains('files.first.fileType == FileType.text')));
    });
  });
}

String _readAsset(String path) => File(path).readAsStringSync();
