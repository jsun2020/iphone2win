import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('USB mode is additive', () {
    test('HomePage keeps existing tabs and adds USB as a fourth tab', () {
      final source = File('lib/pages/home_page.dart').readAsStringSync();

      expect(source, contains('HomeTab.receive'));
      expect(source, contains('HomeTab.send'));
      expect(source, contains('HomeTab.settings'));
      expect(source, contains('HomeTab.usb'));
      expect(source, contains('UsbTab'));
    });

    test('Receive QR upload and Send QR download entries remain wired', () {
      final receiveTab = File('lib/pages/tabs/receive_tab.dart').readAsStringSync();
      final sendTab = File('lib/pages/tabs/send_tab.dart').readAsStringSync();
      final uploadJs = File('assets/web/upload.js').readAsStringSync();
      final mainJs = File('assets/web/main.js').readAsStringSync();

      expect(receiveTab, contains("ValueKey('qr-upload-btn')"));
      expect(sendTab, contains('onTapShareViaLink'));
      expect(sendTab, contains('Icons.qr_code'));
      expect(uploadJs, contains('/api/iphone2win/v1/clipboard-text'));
      expect(mainJs, contains('copyTextFromTextarea'));
    });
  });
}
