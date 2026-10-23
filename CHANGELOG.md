# Changelog

## 1.0.4 — 2026-10-23

- Updates the MeshStreamKit XCFramework distribution to native SDK 1.0.4.
- Includes iOS device, universal iOS simulator, and universal macOS slices.

Version and binary verification details: `releases/1.0.4.json`.

## 1.0.2 — 2026-10-20

- Adds an instance-level `P2PClient.close` API so an app can release the client
  and the sessions it owns without affecting other clients in the process.
- Refreshes the iOS/macOS XCFramework distribution for the current native SDK
  release.

Version and binary verification details: `releases/1.0.2.json`.

## 1.0.0 — 2026-10-18

首个正式稳定版 Apple 二进制分发版本。

- 提供 iOS 真机、Intel/Apple Silicon 模拟器及 macOS Intel/Apple Silicon 的 XCFramework。
- 完善播放生命周期、应用前后台处理和诊断日志能力。
- 提供 SPM、CocoaPods 和手动集成入口。

版本与二进制校验信息见 `releases/1.0.0.json`。

## 0.1.0 — 2026-10-18

首个 Apple 二进制分发版本，包含 iOS 真机/双架构模拟器和 macOS Intel/Apple Silicon。

- 提供 SPM、CocoaPods 和手动 XCFramework 接入方式。
- 支持 AVPlayer 及兼容第三方播放器接入。
- 提供 P2P 分发与 HTTP/CDN 播放支持。
- 支持实例级日志等级，以及可选的本地滚动日志文件。
- 提供不包含客户 SDK Key 的 iOS/macOS Demo。

版本与二进制校验信息见 `releases/0.1.0.json`。应用发布前请按实际业务完成隐私披露与目标设备兼容性验证。
