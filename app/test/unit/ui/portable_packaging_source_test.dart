import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('portable packaging source', () {
    test('script includes libimobiledevice tools when present', () {
      final script = File(
        '../scripts/package_windows_portable.ps1',
      ).readAsStringSync();

      expect(script, contains(r'tools\libimobiledevice'));
      expect(script, contains('iphone2win-portable-files.zip'));
      expect(script, contains('Compress-Archive'));
      expect(script, contains('run_iphone2win.cmd'));
    });

    test('script still packages base features when tools are absent', () {
      final script = File(
        '../scripts/package_windows_portable.ps1',
      ).readAsStringSync();

      expect(
        script,
        contains('if (Test-Path -LiteralPath \$LibimobiledeviceTools)'),
      );
      expect(script, contains('Automatic USB tools not found'));
    });

    test('script creates a single-file portable executable with IExpress', () {
      final script = File(
        '../scripts/package_windows_portable.ps1',
      ).readAsStringSync();

      expect(script, contains('iexpress.exe'));
      expect(script, contains('iphone2win-portable.exe'));
      expect(script, contains('AppLaunched=cmd.exe /c run_iphone2win.cmd'));
    });
  });
}
