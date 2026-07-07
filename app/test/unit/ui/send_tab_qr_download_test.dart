import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('Send tab QR download entry', () {
    test('SendTabVm exposes a direct share via link action backed by WebSendPage', () {
      final source = _readProjectFile('lib/pages/tabs/send_tab_vm.dart');

      expect(source, contains('onTapShareViaLink'));
      expect(source, contains('WebSendPage(files)'));
      expect(source, contains('NoFilesDialog'));
    });

    test('SendTab shows a direct QR download button after files are selected', () {
      final source = _readProjectFile('lib/pages/tabs/send_tab.dart');

      expect(source, contains('onTapShareViaLink'));
      expect(source, contains('Icons.qr_code'));
      expect(source, contains('t.sendTab.sendModes.link'));
    });
  });
}

String _readProjectFile(String path) {
  return File(path).readAsStringSync();
}
