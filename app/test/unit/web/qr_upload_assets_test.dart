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

    test('HTML exposes an explicit text paste form for clipboard transfer', () {
      final html = _readAsset('assets/web/upload.html');

      expect(html, contains('id="clipboardText"'));
      expect(html, contains('id="pasteText"'));
      expect(html, contains('id="sendText"'));
    });

    test('JavaScript sends pasted text to the local clipboard endpoint only', () {
      final js = _readAsset('assets/web/upload.js');

      expect(js, contains('/api/iphone2win/v1/clipboard-text'));
      expect(js, contains('navigator.clipboard.readText'));
      expect(js, contains('sendTextButton'));
    });

    test('ReceiveController serves the local upload page assets', () {
      final source = _readAsset('lib/provider/network/server/controller/receive_controller.dart');

      expect(source, contains('qrUploadPath'));
      expect(source, contains('qrUploadScriptPath'));
      expect(source, contains('Assets.web.uploadHtml'));
      expect(source, contains('Assets.web.uploadJs'));
    });

    test('ReceiveController exposes a PIN-protected local clipboard text endpoint', () {
      final source = _readAsset('lib/provider/network/server/controller/receive_controller.dart');

      expect(source, contains('qrClipboardTextPath'));
      expect(source, contains('Clipboard.setData'));
      expect(source, contains('receivePin'));
    });
  });
}

String _readAsset(String path) => File(path).readAsStringSync();
