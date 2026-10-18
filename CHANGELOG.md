# Changelog

## 0.1.0 — 2026-10-18

首个 Apple 二进制分发版本，包含 iOS 真机/双架构模拟器和 macOS Intel/Apple Silicon。

- 提供 SPM、远程 CocoaPods podspec 和手动 XCFramework 接入方式。
- 统一播放器 URL 代理，流式 CDN 转发与后台 P2P 启动。
- 包含当前 Token 刷新、生命周期、停止取消及互通修复。
- 支持实例级日志等级，以及可选的本地滚动日志文件。
- 提供不包含客户 SDK Key 的 iOS/macOS Demo。

二进制校验值与构建来源见 `releases/0.1.0.json`。本版本未声称完成 App Store 隐私合规或所有设备的性能验收。
