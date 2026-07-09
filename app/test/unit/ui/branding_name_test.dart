import 'dart:io';

import 'package:test/test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('iphone2win branding', () {
    test('Windows runner uses iphone2win for visible app identity', () {
      final cmake = _read('windows/CMakeLists.txt');
      final runner = _read('windows/runner/main.cpp');
      final resources = _read('windows/runner/Runner.rc');
      final manifest = File('windows/iphone2win.exe.manifest');

      expect(cmake, contains('set(BINARY_NAME "iphone2win")'));
      expect(runner, contains('window.Create(L"iphone2win"'));
      expect(resources, contains('VALUE "FileDescription", "iphone2win"'));
      expect(resources, contains('VALUE "InternalName", "iphone2win"'));
      expect(resources, contains('VALUE "OriginalFilename", "iphone2win.exe"'));
      expect(resources, contains('VALUE "ProductName", "iphone2win"'));
      expect(manifest.existsSync(), isTrue);
      expect(manifest.readAsStringSync(), contains('applicationId="iphone2win"'));
    });

    test('browser transfer pages use iphone2win branding', () {
      final downloadPage = _read('assets/web/index.html');
      final uploadPage = _read('assets/web/upload.html');
      final forbiddenPage = _read('assets/web/error-403.html');

      expect(downloadPage, contains('<title>iphone2win</title>'));
      expect(downloadPage, contains('>iphone2win</h1>'));
      expect(uploadPage, contains('<title>iphone2win</title>'));
      expect(uploadPage, contains('>iphone2win</h1>'));
      expect(forbiddenPage, contains('<title>iphone2win</title>'));
    });

    test('primary localized app names are iphone2win', () {
      final english = _read('assets/i18n/en.json');
      final chinese = _read('assets/i18n/zh-CN.json');

      expect(english, contains('"appName": "iphone2win"'));
      expect(chinese, contains('"appName": "iphone2win"'));
      expect(english, isNot(contains('LocalSend')));
      expect(chinese, isNot(contains('LocalSend')));
    });

    test('hardcoded visible labels do not use the old product name', () {
      final logo = _read('lib/widget/local_send_logo.dart');
      final homePage = _read('lib/pages/home_page.dart');

      expect(logo, isNot(contains("'LocalSend'")));
      expect(homePage, isNot(contains("'LocalSend'")));
      expect(logo, contains("'iphone2win'"));
      expect(homePage, contains("'iphone2win'"));
    });

    test('system-visible app integration names use iphone2win', () {
      final persistence = _read('lib/provider/persistence_provider.dart');
      final contextMenu = _read('lib/util/native/context_menu_helper.dart');
      final autoStart = _read('lib/util/native/autostart_helper.dart');
      final troubleshoot = _read('lib/pages/troubleshoot_page.dart');
      final security = _read('lib/util/security_helper.dart');
      final initError = _read('lib/config/init_error.dart');

      expect(persistence, contains(r'$appData\\iphone2win\\settings.json'));
      expect(persistence, isNot(contains(r'$appData\\LocalSend\\settings.json')));
      expect(contextMenu, contains("const _windowsFileName = 'iphone2win';"));
      expect(autoStart, contains("const _windowsRegistryKeyValue = 'iphone2win';"));
      expect(troubleshoot, contains('rule name="iphone2win"'));
      expect(troubleshoot, isNot(contains('rule name="LocalSend"')));
      expect(security, contains("'CN': 'iphone2win User'"));
      expect(initError, contains('iphone2win \${info.version}'));
      expect(initError, contains("title: 'iphone2win: Error'"));
    });

    test('platform launch surfaces use iphone2win display name', () {
      final webIndex = _read('web/index.html');
      final webManifest = _read('web/manifest.json');
      final androidMain = _read('android/app/src/main/AndroidManifest.xml');
      final androidDebug = _read('android/app/src/debug/AndroidManifest.xml');

      expect(webIndex, contains('content="iphone2win"'));
      expect(webIndex, contains('<title>iphone2win</title>'));
      expect(webManifest, contains('"name": "iphone2win"'));
      expect(webManifest, contains('"short_name": "iphone2win"'));
      expect(androidMain, contains('android:label="iphone2win"'));
      expect(androidDebug, contains('android:label="iphone2win Debug"'));
    });
  });
}
