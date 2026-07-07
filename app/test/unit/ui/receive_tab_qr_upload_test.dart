import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('Receive tab QR upload entry', () {
    test('ReceiveTabVm exposes a local QR upload URL and HTTP preparation action', () {
      final source = _readProjectFile('lib/pages/tabs/receive_tab_vm.dart');

      expect(source, contains('buildQrUploadUrl'));
      expect(source, contains('qrUploadUrl'));
      expect(source, contains('prepareQrUpload'));
      expect(source, contains('restartServer('));
      expect(source, contains('https: false'));
    });

    test('ReceiveTab shows a QR upload button backed by QrDialog', () {
      final source = _readProjectFile('lib/pages/tabs/receive_tab.dart');

      expect(source, contains('QrDialog'));
      expect(source, contains('Icons.qr_code'));
      expect(source, contains('prepareQrUpload'));
      expect(source, contains('qrUploadUrl'));
    });
  });
}

String _readProjectFile(String path) {
  return File(path).readAsStringSync();
}
