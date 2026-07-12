# 参与 iphone2win 开发

iphone2win 聚焦 iPhone/iPad 与 Windows 之间的本地文件传输。提交的代码、测试和文档应服务于局域网、二维码、USB、隐私或 Windows/iOS 兼容性，不引入与本项目无关的平台功能、分发渠道或上游宣传内容。

## 开发环境

- Flutter 3.38.10（见 `.fvmrc`）和兼容的 Dart SDK；
- Windows 开发需要 Visual Studio 的“使用 C++ 的桌面开发”工作负载；
- iOS 开发和构建需要 macOS、Xcode 和有效的本地签名配置；
- 自动 USB 联调需要 Apple Devices/iTunes 提供的 Apple Mobile Device 驱动，以及本地 `libimobiledevice` 命令行工具。

`tools/libimobiledevice/`、`dist/`、编译产物、Apple 专有驱动和本机配置不得提交到仓库。

## 本地启动

```powershell
cd app
flutter pub get
dart run build_runner build -d
flutter run -d windows
```

修改模型、映射或生成代码相关源文件后，应重新运行 `build_runner`，不要只手工修改生成文件。

## 项目约束

### 隐私

不得引入公网发现、信令、STUN、TURN、中继、云同步、账号、遥测、分析、崩溃上报、广告、应用内购买或捐赠 SDK。不得在启动、发现或传输过程中向第三方发送设备别名、型号、版本、令牌、指纹、公网 IP 或文件元数据。

二维码网页必须随应用本地打包，只访问当前 Windows 应用的同源接口，不加载远程脚本、字体、图片或统计资源。

### USB

- 自动 USB 仅访问 iphone2win 的 iOS File Sharing Documents 目录；
- 不访问照片/DCIM、其他应用容器或系统文件；
- 调用外部工具时必须使用可执行文件和参数列表，不拼接 shell 命令；
- 日志和错误信息不得无必要地暴露完整设备标识；
- 工具缺失时应保留局域网、二维码和手动 USB 的可用性。

### 兼容性

新增 USB 能力不得删除或破坏现有发送、接收、二维码上传、二维码下载和文本传输。涉及 iOS bundle id 的修改会影响应用身份、文件共享定位和已有数据，应作为独立迁移处理。

## 测试与检查

提交前至少运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\privacy_audit.ps1
cd app
flutter analyze
flutter test
flutter build windows --debug
```

改动范围较小时可先运行对应的 `app/test/unit/` 测试，但提交前仍应完成全量测试。涉及 Rust 核心时还应运行：

```powershell
cargo test --manifest-path .\app\rust\Cargo.toml
```

涉及 iOS 的变更需在 macOS/Xcode 环境补充构建或真机验证，并在变更说明中注明未能执行的检查。

## 提交要求

1. 一个变更只解决一个清晰问题，并同步更新相关测试和文档。
2. 提交信息简洁说明类型和范围，例如 `feat(usb): ...`、`fix(qr): ...`、`docs: ...`。
3. 合并请求说明应包含：问题背景、实现内容、隐私影响、验证命令和结果、需要的手工验证。
4. UI 变更应附 Windows 或 iPhone 的截图；传输问题应提供复现步骤、两端系统版本、网络/USB 环境和已脱敏日志。
5. 安全或隐私问题不要在公开讨论中附带未脱敏的设备标识、网络地址或文件内容；先向项目维护者私下报告。

## 手工验收建议

- 同一局域网内完成 iPhone → Windows 和 Windows → iPhone 传输；
- 使用二维码完成浏览器上传、文件下载和文本复制；
- 在开启/关闭自动接收及 PIN 的情况下检查接收行为；
- USB 工具缺失、无设备、未信任、已信任等状态均显示可执行的提示；
- 使用 USB 分别推送和拉取文件，并验证同名文件不会被静默覆盖；
- Windows 便携包在包含和不包含 USB 工具时都能启动。
