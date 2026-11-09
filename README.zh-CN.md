# MeshStreamKit：iOS / macOS P2P SDK

[English](README.md) · [官网](https://meshstream.net/zh/) · [接入文档](https://meshstream.net/zh/docs/sdk/ios-setup/) · [CocoaPods](https://cocoapods.org/pods/MeshStreamKit) · [在线 Demo](https://demo.meshstream.net/)

MeshStreamKit 是面向 Swift / Objective-C 应用的 iOS 与 macOS P2P 视频、音频流媒体 SDK。它为 AVPlayer 或其他支持 URL 的播放器提供本地播放地址，在可用时使用点对点分发，P2P 不可用时回退到 HTTP/CDN。

当前版本：`1.0.10`。

## 产品能力

- 通过统一会话 API 接入 HLS、MPEG-DASH 和支持 HTTP Range 的 MP4/MP3。
- 支持 Swift、Objective-C，可配合 AVPlayer 或其他兼容播放器使用。
- 提供预加载、会话流量统计、Peer 事件与诊断接口。
- 支持 Swift Package Manager 与 CocoaPods，提供 iOS 真机及 iOS 模拟器、macOS 双架构组件。

媒体解码与格式兼容性取决于所选播放器和平台；P2P 可用性取决于网络条件及持有相同内容的 Peer。

## 环境要求

| 环境 | 最低系统版本 |
| --- | --- |
| iOS 真机 | iOS 15 |
| iOS 模拟器（Intel / Apple Silicon） | iOS 15 / iOS 15 |
| macOS（Intel / Apple Silicon） | macOS 12 / macOS 12 |

SPM 安装需要支持 Swift Tools 5.9 的 Xcode。Objective-C 工程也可通过 SPM 安装，无需转换工程语言。

## 安装

同一 App Target 请选择一种安装方式，避免重复引入。

### Swift Package Manager

在 Xcode 中选择 **File → Add Package Dependencies**，输入：

```text
https://github.com/Mesh-Stream/meshstream-p2p-ios-sdk.git
```

选择最新稳定版本，将 `MeshStreamKit` 产品加入 App Target。

### CocoaPods

在 Podfile 中添加：

```ruby
platform :ios, '15.0'

target 'YourApp' do
  pod 'MeshStreamKit'
end
```

首次安装执行 `pod install --repo-update`，随后打开生成的 `.xcworkspace`。macOS 工程使用 `platform :osx, '12.0'`。

SDK 已发布至 CocoaPods Trunk。已有项目使用的版本化远程 `:podspec` 安装入口仍可继续使用；不要改用 `:git` 安装。

### 手动集成

下载 [MeshStreamKit 1.0.10](https://sdk.meshstream.net/apple/1.0.10/MeshStreamKit.zip)，解压后将 `MeshStreamKit.xcframework` 添加到 App Target，设置为 **Embed & Sign**。

版本及 SHA-256 校验信息见 [版本清单](releases/1.0.10.json)。

## 快速接入

先在控制台创建应用并获取对应平台的 SDK Key。应用的 Bundle ID 必须与控制台登记信息一致。

以下以 AVPlayer 为例，`mediaURL` 为业务播放地址，`client`、`session` 和 `player` 由页面或播放管理器持有：

```objc
#import <AVFoundation/AVFoundation.h>
#import <MeshStreamKit/MeshStreamKit.h>

P2PConfig *config = [[P2PConfig alloc] initWithKey:@"YOUR_IOS_SDK_KEY"];
NSError *error = nil;
self.client = [P2PSDK clientWithConfig:config error:&error];
if (!self.client) {
    NSLog(@"SDK initialization failed: %@", error);
    return;
}

self.session = [self.client createPlaybackSessionWithURL:mediaURL error:&error];
if (!self.session) {
    NSLog(@"Playback session creation failed: %@", error);
    return;
}

self.player = [AVPlayer playerWithURL:self.session.playbackUrl];
[self.player play];
```

第三方播放器使用同一个 `session.playbackUrl`。如需预加载，可选调用 `[session preload]`；不调用也可正常播放。

切换视频或离开播放页时，先暂停播放器并解除其对旧播放 Item 的引用，再调用 `[session close]`。应用不再使用 SDK 时，可调用 `[P2PSDK shutdown]` 关闭所有 SDK 客户端。

### 应用配置

- iOS：在 Info.plist 中设置 `NSAppTransportSecurity → NSAllowsLocalNetworking = YES`，参考 Demo。媒体源的其他 ATS 例外按业务需要配置，不建议直接放开所有网络请求。
- macOS：开启 App Sandbox 时，添加 `com.apple.security.network.client` 和 `com.apple.security.network.server` 权限。
- 后台播放、音频会话及画中画按应用需求和播放器文档配置。

### 诊断日志

日志默认关闭。如需排查问题，在创建客户端前配置：

```objc
config.logLevel = P2PLogLevelInfo;
config.fileLoggingEnabled = YES;
```

文件日志保存在应用的 Caches 目录中，支持滚动清理，不自动上传。生产环境建议按需启用；提交诊断资料前，请移除 SDK Key、访问凭据及敏感播放地址。

## 示例工程

- iOS：打开 `Examples/iOS/MeshStreamKitDemo.xcodeproj`，选择自己的签名 Team 与 Bundle ID，填写对应 SDK Key 后运行。
- macOS：在 `Examples/macOS` 中执行 `swift run MeshStreamKitMacDemo`，填写对应 SDK Key 后测试。

示例不内置客户 SDK Key。正式接入前，请根据业务场景完成目标设备、网络条件和播放器兼容性测试。

## 商业授权与支持

MeshStreamKit 为商业 SDK，使用与分发以适用的商业授权协议为准。本仓库提供接入资料及示例，不授予 SDK 内部实现的额外使用权。

- 应用与 SDK Key 管理：[MeshStream 控制台](https://console.meshstream.net/)
- 商务与技术支持：[meshstreamsupport@gmail.com](mailto:meshstreamsupport@gmail.com)
- 更新说明：[CHANGELOG](CHANGELOG.md)
- 授权与第三方声明：[LICENSE](LICENSE) · [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES.md)

集成方应保留适用的第三方声明，并根据实际业务完成应用商店隐私披露及发布配置。

## 其他 MeshStream SDK

- [Web](https://github.com/Mesh-Stream/meshstream-p2p-web-sdk): JavaScript / TypeScript、WebRTC 与浏览器播放器.
- [Android](https://github.com/Mesh-Stream/meshstream-p2p-android-sdk): Kotlin / Java、Maven 与 Media3 / ExoPlayer.
- [Windows](https://github.com/Mesh-Stream/meshstream-p2p-Windows-sdk): 面向 Windows 10 / 11 x64 的 C / C++ 接口.
- [uni-app](https://github.com/Mesh-Stream/meshstream-p2p-uniapp-sdk): 面向 iOS / Android App 的 UTS / JavaScript 插件.
- [Flutter](https://github.com/Mesh-Stream/meshstream-p2p-flutter-sdk): 面向 iOS / Android 的 Dart 插件及 video_player 示例.
- [React Native](https://github.com/Mesh-Stream/meshstream-p2p-react-native-sdk): 面向 iOS / Android 的 TypeScript API 及 react-native-video 示例.
