# iphone2win QR Upload Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a LAN-only QR browser upload flow from iPhone to the Windows receiver.

**Architecture:** Reuse the existing LocalSend v2 receive protocol and save path. Serve a local browser upload page from the existing app server, generate a QR URL on the Receive tab, and let the browser call the existing prepare-upload/upload endpoints.

**Tech Stack:** Flutter/Dart, existing `SimpleServer`, existing `ReceiveController`, static browser HTML/JavaScript assets, Flutter widget/unit tests, PowerShell privacy audit.

---

## File Structure

- Create `app/lib/util/qr_upload_url.dart`: local upload route constants and URL builder.
- Create `app/test/unit/util/qr_upload_url_test.dart`: unit tests for URL generation.
- Create `app/assets/web/upload.html`: local-only browser upload page.
- Create `app/assets/web/upload.js`: local-only browser upload client.
- Create `app/test/unit/web/qr_upload_assets_test.dart`: static asset tests for privacy and protocol endpoints.
- Modify `app/lib/provider/network/server/controller/receive_controller.dart`: serve `/upload` and `/upload.js`.
- Modify `app/lib/pages/tabs/receive_tab_vm.dart`: expose QR upload URL/action.
- Modify `app/lib/pages/tabs/receive_tab.dart`: add QR button and dialog.
- Regenerate `app/lib/gen/assets.gen.dart`.
- Update `docs/privacy.md`: document LAN QR upload behavior.
- Update `docs/privacy-audit-results.md`: record verification after implementation.

## Task 1: QR Upload URL Utility

**Files:**
- Create: `app/lib/util/qr_upload_url.dart`
- Create: `app/test/unit/util/qr_upload_url_test.dart`

- [ ] **Step 1: Write the failing URL utility tests**

Create `app/test/unit/util/qr_upload_url_test.dart` with tests that assert:

- offline server returns `null`;
- running server with no local IP returns `null`;
- running server with `https: false` returns `http://<first-ip>:<port>/upload`;
- running server with `https: true` still returns an HTTP URL because QR browser upload uses LAN HTTP mode.

- [ ] **Step 2: Run the test and confirm RED**

Run:

```powershell
flutter test test/unit/util/qr_upload_url_test.dart
```

Expected: fails because `qr_upload_url.dart` does not exist.

- [ ] **Step 3: Implement the utility**

Create `app/lib/util/qr_upload_url.dart` with:

- `const qrUploadPath = '/upload';`
- `const qrUploadScriptPath = '/upload.js';`
- `String? buildQrUploadUrl({required ServerState? serverState, required List<String> localIps})`

The builder returns `null` when server is offline or no IP is available. Otherwise it returns an HTTP URL using the first IP and server port.

- [ ] **Step 4: Run the test and confirm GREEN**

Run:

```powershell
flutter test test/unit/util/qr_upload_url_test.dart
```

Expected: pass.

- [ ] **Step 5: Commit**

```powershell
git add app/lib/util/qr_upload_url.dart app/test/unit/util/qr_upload_url_test.dart
git commit -m "test: add qr upload url builder"
```

## Task 2: Browser Upload Assets

**Files:**
- Create: `app/assets/web/upload.html`
- Create: `app/assets/web/upload.js`
- Create: `app/test/unit/web/qr_upload_assets_test.dart`
- Modify generated: `app/lib/gen/assets.gen.dart`

- [ ] **Step 1: Write failing asset tests**

Create `app/test/unit/web/qr_upload_assets_test.dart` with tests that read `assets/web/upload.html` and `assets/web/upload.js` from disk and assert:

- no `http://` or `https://` remote URL appears in either asset;
- `upload.html` references only `/upload.js`;
- `upload.js` references `/api/localsend/v2/prepare-upload`;
- `upload.js` references `/api/localsend/v2/upload`;
- `upload.js` uses `fetch`;
- `upload.js` includes `pin` handling for receive PIN.

- [ ] **Step 2: Run the test and confirm RED**

Run:

```powershell
flutter test test/unit/web/qr_upload_assets_test.dart
```

Expected: fails because the assets do not exist.

- [ ] **Step 3: Add the upload HTML asset**

Create a self-contained `upload.html` with a compact mobile-first UI:

- title `iphone2win`;
- file input with `multiple`;
- optional PIN text field;
- upload button;
- status list;
- local script tag `<script src="/upload.js"></script>`.

- [ ] **Step 4: Add the upload JavaScript asset**

Create `upload.js` that:

- reads selected files;
- creates a v2 prepare-upload payload with browser-local sender info;
- appends `?pin=<pin>` to prepare-upload when provided;
- posts JSON to `/api/localsend/v2/prepare-upload`;
- uploads each selected file to `/api/localsend/v2/upload?sessionId=...&fileId=...&token=...`;
- uses each `File` object as the request body and sets `Content-Type` plus `Content-Length`;
- reports pending, rejected, failed, and complete states in the page.

- [ ] **Step 5: Regenerate assets**

Run:

```powershell
dart run build_runner build -d
```

Expected: `Assets.web.upload` and `Assets.web.uploadJs` are generated.

- [ ] **Step 6: Run asset tests and confirm GREEN**

Run:

```powershell
flutter test test/unit/web/qr_upload_assets_test.dart
```

Expected: pass.

- [ ] **Step 7: Commit**

```powershell
git add app/assets/web/upload.html app/assets/web/upload.js app/lib/gen/assets.gen.dart app/test/unit/web/qr_upload_assets_test.dart
git commit -m "feat: add local browser upload assets"
```

## Task 3: Serve QR Upload Routes

**Files:**
- Modify: `app/lib/provider/network/server/controller/receive_controller.dart`

- [ ] **Step 1: Write failing route/asset coverage**

Extend `app/test/unit/web/qr_upload_assets_test.dart` or add a focused unit test that asserts `ReceiveController` source references `qrUploadPath`, `qrUploadScriptPath`, `Assets.web.upload`, and `Assets.web.uploadJs`.

- [ ] **Step 2: Run the focused test and confirm RED**

Run:

```powershell
flutter test test/unit/web/qr_upload_assets_test.dart
```

Expected: fails until routes are wired.

- [ ] **Step 3: Install local upload routes**

In `ReceiveController.installRoutes`, add:

- `router.get(qrUploadPath, ...)` responding with `Assets.web.upload`;
- `router.get(qrUploadScriptPath, ...)` responding with `Assets.web.uploadJs` and JavaScript content type.

- [ ] **Step 4: Run the focused test and confirm GREEN**

Run:

```powershell
flutter test test/unit/web/qr_upload_assets_test.dart
```

Expected: pass.

- [ ] **Step 5: Commit**

```powershell
git add app/lib/provider/network/server/controller/receive_controller.dart app/test/unit/web/qr_upload_assets_test.dart
git commit -m "feat: serve local qr upload page"
```

## Task 4: Receive Tab QR Entry

**Files:**
- Modify: `app/lib/pages/tabs/receive_tab_vm.dart`
- Modify: `app/lib/pages/tabs/receive_tab.dart`

- [ ] **Step 1: Write failing view-model coverage**

Extend `app/test/unit/util/qr_upload_url_test.dart` if needed to cover URL availability. The production UI should use the utility result and disable QR action when it is `null`.

- [ ] **Step 2: Add view-model fields**

Add `qrUploadUrl` and `prepareQrUpload` to `ReceiveTabVm`.

`prepareQrUpload` restarts the current server with `https: false` when needed so the browser URL works over LAN HTTP. It returns the rebuilt HTTP upload URL or `null` if the server is offline/no IP.

- [ ] **Step 3: Add the QR icon button**

Add a QR icon button near the existing history/info buttons. Disable it when `qrUploadUrl == null`. On tap, call `prepareQrUpload`, then open `QrDialog(data: url, label: url)`.

- [ ] **Step 4: Run targeted tests**

Run:

```powershell
flutter test test/unit/util/qr_upload_url_test.dart
flutter analyze
```

Expected: pass.

- [ ] **Step 5: Commit**

```powershell
git add app/lib/pages/tabs/receive_tab_vm.dart app/lib/pages/tabs/receive_tab.dart
git commit -m "feat: add receive qr upload action"
```

## Task 5: Documentation And Verification

**Files:**
- Modify: `docs/privacy.md`
- Modify: `docs/privacy-audit-results.md`

- [ ] **Step 1: Update privacy docs**

Document that QR upload serves a local-only browser page from the receiver and uses existing LAN upload endpoints.

- [ ] **Step 2: Run full verification**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\privacy_audit.ps1
flutter test
flutter analyze
cargo test --manifest-path .\app\rust\Cargo.toml
flutter build windows --debug
```

Expected: all pass. If Windows build fails with `LNK1168`, stop any running `localsend_app.exe` process and rerun once.

- [ ] **Step 3: Update verification snapshot**

Record the new QR upload tests and build result in `docs/privacy-audit-results.md`.

- [ ] **Step 4: Commit**

```powershell
git add docs/privacy.md docs/privacy-audit-results.md
git commit -m "docs: document qr upload verification"
```

- [ ] **Step 5: Final state check**

Run:

```powershell
git status --short --untracked-files=no
git log --oneline -8
```

Expected: clean working tree on the feature branch.
