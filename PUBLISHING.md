# 发布 iphone2win

iphone2win 使用 GitHub Actions 构建 Windows x64 发布包。工作流位于 `.github/workflows/build-release-windows.yml`。

## 测试构建

在 GitHub 仓库的 Actions 页面选择 **Build & Release (Windows)**，点击 **Run workflow**。手动运行只生成可下载的 Actions artifact，不创建公开 Release。

## 发布新版本

1. 更新 `app/pubspec.yaml` 中的版本号，例如 `0.2.0+2`。
2. 同步更新 `scripts/compile_windows_exe-inno.iss` 中的 `MyAppVersion`。
3. 更新 `app/assets/CHANGELOG.md`、README 和其他受影响文档。
4. 完成隐私审计、测试和 Windows release 构建。
5. 提交并推送 `main`。
6. 创建与应用版本一致的标签并推送：

```powershell
git tag -a v0.2.0 -m "iphone2win v0.2.0"
git push origin v0.2.0
```

工作流会自动创建 GitHub Release，并上传：

- `iphone2win-<版本>-windows-x64-portable.exe`；
- `iphone2win-<版本>-windows-x64.zip`；
- `SHA256SUMS.txt`。

标签必须与 `app/pubspec.yaml` 的三段版本一致，否则工作流会停止发布。

## 发布包说明

- EXE 和 ZIP 均为未签名的 Windows x64 便携包；
- ZIP 解压后直接运行 `iphone2win.exe`；
- 单文件 EXE 在临时目录展开应用后启动；
- `tools/libimobiledevice/` 存在于构建环境时会被打入发布包；标准 GitHub runner 默认不包含这些可选工具；
- Apple Devices/iTunes 提供的专有驱动不会随项目分发。
