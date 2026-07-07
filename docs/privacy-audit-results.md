# Privacy Audit Results

This snapshot records the privacy-hardening verification for iphone2win on
2026-07-07 in the Windows workspace.

Commands run:

- `powershell -ExecutionPolicy Bypass -File .\scripts\privacy_audit.ps1`
  - Result: passed.
- `flutter pub get`
  - Result: passed. The lockfile was not changed and no `in_app_purchase` dependency was reintroduced.
- `dart run build_runner build -d`
  - Result: passed. The generator completed; only unrelated generated-file formatting churn appeared locally and was not committed.
- `flutter analyze`
  - Result: passed with `No issues found!`.
- `flutter test`
  - Result: passed, 67 tests.
- `flutter test test/unit/ui/receive_tab_qr_upload_test.dart test/unit/util/qr_upload_url_test.dart test/unit/web/qr_upload_assets_test.dart`
  - Result: passed, 10 focused QR upload tests.
- `cargo test --manifest-path .\app\rust\Cargo.toml`
  - Result: passed, 0 Rust tests. Existing upstream/FRB warnings remain.
- `flutter build windows --debug`
  - Result: passed and built `build\windows\x64\runner\Debug\localsend_app.exe`.

Expected privacy outcome:

- No LocalSend public signaling host remains in active audited app paths.
- No LocalSend public STUN host remains in active audited app paths.
- No Google public STUN sample remains in scanned paths.
- No `in_app_purchase` dependency remains.
- No generated StoreKit purchase plugin remains.
- No known analytics, crash reporting, ads, or telemetry SDK reference remains in active audited app paths.
- QR upload URL generation uses only the first local IP address, the current local port, and `/upload`.
- The QR code does not include alias, version, device model, device type, token, fingerprint, or public IP address.
- The bundled QR upload page and script contain no remote `http://` or `https://` references and call only same-origin LocalSend v2 upload endpoints.

Windows build note:

- The upstream Windows CMake configuration referenced `localsend_msix_helper.msix`, but that binary asset is not present in this repository checkout. The install rule is now optional, so the normal Windows debug build can complete without requiring that packaging helper.

iOS build note:

- iOS build verification requires macOS and Xcode. This Windows workspace cannot run the iOS simulator or App Store build locally.
