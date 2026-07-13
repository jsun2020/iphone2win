# 更新日志

本文件只记录 iphone2win 相对于上游 LocalSend 的项目变更。

## 0.1.0（2026-07-13）

- 首个 iphone2win GitHub Release，可直接下载 Windows x64 单文件 EXE 或 ZIP。
- 新增标签触发的 Windows 自动构建、SHA-256 校验和 GitHub Release 发布流程。
- 完善项目 README、贡献指南、更新日志和产品需求文档。

## 2026-07-10

### 新增

- 新增 Windows 自动 USB 控制：检测 iPhone、检查配对/信任状态、从 iPhone `USB-Outbox` 拉取文件，以及将发送页选定文件推送到 iPhone `USB-Inbox`。
- 新增基于 `libimobiledevice` 的工具解析、命令执行、iOS 设备检测和 AFC/HouseArrest 文件服务。
- Windows 便携包在 `tools/libimobiledevice/` 存在时自动包含 USB 工具；工具缺失时仍可打包并使用其他传输方式。

### 修复

- 加强 USB 诊断、设备列表失败和 AFC 命令级错误的识别与提示。
- 加强拉取结果解析和同名文件冲突处理，避免覆盖已有文件。
- 便携 EXE 打包时等待 IExpress 完成并校验产物。

## 2026-07-09

### 新增

- 新增 USB 页面及 `USB-Inbox`、`USB-Outbox` 本地目录工作流。
- 支持将发送页选定文件和剪贴板文本导出到 `USB-Outbox`。
- 保留局域网发送、接收、二维码上传、二维码下载和文本传输入口。
- 完成 iphone2win 的界面品牌调整和 Windows 可执行文件配置。
- 增加自动 USB 工具、命令、设备、文件服务和便携打包的源码保护测试。

## 2026-07-07

### 新增

- 建立 iphone2win 的局域网优先隐私边界和自动化隐私审计脚本。
- 新增 iPhone 扫码向 Windows 上传文件的本地网页和接收页二维码入口。
- 新增 Windows 选择文件后供 iPhone 扫码下载的快捷入口。
- 浏览器下载页支持预览并复制文本内容。

### 变更

- 移除应用内购买和商店捐赠依赖及入口。
- 禁用公网 WebRTC 信令启动路径，移除默认公网信令/STUN 依赖面。
- Windows MSIX 辅助文件缺失时改为可选，不阻断普通 Windows 构建。

### 文档与验证

- 增加局域网隐私说明、二维码上传设计和隐私审计结果记录。
- 验证依赖解析、代码生成、静态分析、Flutter 测试、Rust 测试和 Windows 调试构建。
