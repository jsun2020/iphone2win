# Windows to iPhone QR Download Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Windows-to-iPhone transfer obvious by adding a direct QR/link-share button after files are selected on the Send tab.

**Architecture:** Reuse the existing `WebSendPage` and `SendMode.link` flow instead of creating another transfer protocol. The new Send tab button calls a ViewModel action that validates the selected file list and navigates to the existing browser download QR page.

**Tech Stack:** Flutter/Dart UI, existing Refena ViewProvider, existing Web Send HTTP routes and bundled `assets/web/index.html` / `main.js`.

---

### Task 1: Add Direct QR Download Entry

**Files:**
- Modify: `app/lib/pages/tabs/send_tab_vm.dart`
- Modify: `app/lib/pages/tabs/send_tab.dart`
- Create: `app/test/unit/ui/send_tab_qr_download_test.dart`

- [ ] **Step 1: Write the failing test**

Create `app/test/unit/ui/send_tab_qr_download_test.dart` with source-level regression checks that the Send tab exposes a direct QR/link-share action and that it navigates to `WebSendPage`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/ui/send_tab_qr_download_test.dart`
Expected: FAIL because `onTapShareViaLink` and the direct QR button are not present yet.

- [ ] **Step 3: Implement minimal ViewModel action**

Add `onTapShareViaLink` to `SendTabVm`. It reads the selected files, shows `NoFilesDialog` when empty, and navigates to `WebSendPage(files)` when files exist.

- [ ] **Step 4: Implement minimal Send tab button**

In the selected-files card, add an `ElevatedButton.icon` with `Icons.qr_code`, label `t.sendTab.sendModes.link`, and `onPressed: () async => await vm.onTapShareViaLink(context)`.

- [ ] **Step 5: Verify targeted tests and analyzer**

Run:
- `flutter test test/unit/ui/send_tab_qr_download_test.dart test/unit/web/qr_upload_assets_test.dart`
- `flutter analyze`

- [ ] **Step 6: Commit**

Commit the UI/test change with message `feat: add send qr download action`.

### Task 2: Final Verification

**Files:**
- No planned source changes unless verification exposes an issue.

- [ ] **Step 1: Run privacy and regression checks**

Run:
- `powershell -ExecutionPolicy Bypass -File .\scripts\privacy_audit.ps1`
- `flutter test`
- `flutter analyze`
- `flutter build windows --debug`

- [ ] **Step 2: Merge back to main if checks pass**

Fast-forward merge `iphone2win-send-qr-download` into `main`, delete the feature branch, and report the executable path.
