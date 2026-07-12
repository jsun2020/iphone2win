# iphone2win

iphone2win 是一个面向 iPhone/iPad 与 Windows 的本地文件传输工具，支持局域网传输、二维码浏览器传输和 USB 数据线传输。

本项目基于 [LocalSend](https://github.com/localsend/localsend) 开发，保留其局域网发现和点对点传输能力，并针对 Apple 设备与 Windows 之间的使用场景增加了二维码和 USB 工作流。项目采用 Apache-2.0 许可证，详见 [LICENSE](LICENSE)。

## 功能

- 局域网双向传输：同一局域网内发现设备，直接发送文件或文本。
- iPhone 扫码上传：Windows 接收页显示本地二维码，iPhone 使用相机或浏览器选择文件并上传。
- iPhone 扫码下载：Windows 选择文件或文本后生成二维码，iPhone 浏览器可下载文件或复制文本。
- 手动 USB 模式：通过 `USB-Inbox` 和 `USB-Outbox`，配合 Windows 的 Apple Devices/iTunes 文件共享交换文件。
- 自动 USB 模式：Windows 可检测已连接且受信任的 iPhone，将 iPhone `USB-Outbox` 拉取到电脑，或将发送页中选定的文件推送至 iPhone `USB-Inbox`。
- 便携版打包：可生成 Windows ZIP、启动脚本和单文件便携 EXE。

## 隐私边界

iphone2win 不使用公网发现、信令、STUN、TURN、中继、遥测、分析、崩溃上报、广告、应用内购买或捐赠 SDK。

局域网模式只允许：

- 本地 UDP 组播发现；
- 发送方与接收方之间的本地 HTTP/HTTPS 直连；
- 浏览器与 Windows 应用之间的同源本地二维码传输。

USB 模式不需要网络，只访问 iphone2win 在 iOS 文件共享中公开的 Documents 目录，不访问其他应用容器或 iPhone 系统目录。完整约束见 [docs/privacy.md](docs/privacy.md)。发布前应运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\privacy_audit.ps1
```

## 使用方式

### 局域网传输

1. 在 iPhone/iPad 和 Windows 上启动 iphone2win。
2. 确保设备连接到同一局域网，并允许应用访问本地网络和 Windows 防火墙。
3. 在“发送”页选择文件或文本，再选择附近设备；接收方确认后开始传输。

### 二维码传输

- iPhone → Windows：在 Windows“接收”页打开二维码，用 iPhone 扫码，在本地网页中选择文件上传。
- Windows → iPhone：在 Windows“发送”页选择文件或文本，点击二维码入口，用 iPhone 扫码下载或复制。

二维码地址使用 Windows 当前局域网 IP。传输期间 Windows 应用必须保持运行；在不可信网络中建议关闭自动接收并启用接收 PIN。

### USB 传输

手动模式需要在 Windows 安装 Apple Devices 或 iTunes，并在 iPhone 上信任此电脑。通过 Apple 文件共享访问 iphone2win：

- Windows 放入 `USB-Inbox` 的文件可在 iPhone 应用中查看；
- iPhone 导出到 `USB-Outbox` 的文件可复制到 Windows。

Windows 自动 USB 模式还需要本地 `libimobiledevice` 工具。便携包可在 `tools/libimobiledevice/` 中携带这些工具；工具缺失时，局域网、二维码和手动 USB 功能仍可使用。项目不会自动下载工具，也不包含 Apple 专有驱动。

## 开发与验证

项目固定使用 Flutter 3.38.10。应用代码位于 `app/`：

```powershell
cd app
flutter pub get
dart run build_runner build -d
flutter analyze
flutter test
flutter build windows --debug
```

iOS 构建需要 macOS 和 Xcode。Windows 便携版的构建方式：

```powershell
cd app
flutter build windows --release
cd ..
powershell -ExecutionPolicy Bypass -File .\scripts\package_windows_portable.ps1
```

产物生成在 `dist/`。如果存在 `tools/libimobiledevice/`，打包脚本会将其一并放入便携包。

贡献前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)，产品范围和验收要求见 [prd.md](prd.md)。
