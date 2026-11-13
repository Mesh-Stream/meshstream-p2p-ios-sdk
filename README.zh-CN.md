# MeshStreamKit：iOS / macOS P2P SDK

[English](README.md) · [官网](https://meshstream.net/zh/) · [接入文档](https://meshstream.net/zh/docs/sdk/ios-setup/) · [CocoaPods](https://cocoapods.org/pods/MeshStreamKit) · [在线 Demo](https://demo.meshstream.net/)

MeshStreamKit 是面向 Swift / Objective-C 应用的 iOS 与 macOS P2P 视频、音频流媒体 SDK。它为 AVPlayer 或其他支持 URL 的播放器提供本地播放地址，在可用时使用点对点分发，P2P 不可用时回退到 HTTP/CDN。

当前版本：`1.1.1`。

## 工作方式

把原始媒体地址交给 SDK 创建会话，再把会话的 `playbackUrl` 交给现有播放器：

```text
应用 → SDK 创建播放会话 → 本地播放地址 → 播放器
                            └─ SDK 从 Peer 或源站/CDN 获取媒体
```

播放器继续负责解码、画面和播放控制；SDK 负责媒体传输、缓存及 P2P 调度。服务配置与 P2P 准备在后台执行，不需要等到 Peer 连接后才开始播放。离开播放页或切换内容时，先停止使用旧播放地址，再关闭旧会话。

## 产品能力

- 通过统一会话 API 接入 HLS、MPEG-DASH 和支持 HTTP Range 的 MP4/MP3。
- 支持 Swift、Objective-C，可配合 AVPlayer 或其他兼容播放器使用。
- 提供预加载、会话流量统计、Peer 事件与诊断接口。
- 支持 Swift Package Manager 与 CocoaPods，提供 iOS 真机及 iOS 模拟器、macOS 双架构组件。

## 接入准备

- 在 [MeshStream 控制台](https://console.meshstream.net/)创建应用和对应平台的 SDK Key；启用身份校验时，登记与运行应用一致的包名或 Bundle ID。
- 准备一个可播放的 HLS `.m3u8`、DASH `.mpd`、支持 Range 的 MP4 或 MP3 地址，建议使用 HTTPS。
- 选择支持该媒体格式的播放器。SDK 提供传输能力，不增加播放器的解码能力；例如 AVPlayer 不原生支持 DASH。

希望先看效果？直接跳到[运行 Demo](#运行-demo)，再按下方步骤接入自己的应用。顶部的在线 Demo 是 Web 体验页，各端示例在本仓库中运行。

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

选择 **Exact Version: 1.1.1**，将 `MeshStreamKit` 产品加入 App Target。

### CocoaPods

在 Podfile 中添加：

```ruby
platform :ios, '15.0'

target 'YourApp' do
  pod 'MeshStreamKit', '1.1.1'
end
```

首次安装执行 `pod install --repo-update`，随后打开生成的 `.xcworkspace`。macOS 工程使用 `platform :osx, '12.0'`。

SDK 已发布至 CocoaPods Trunk。已有项目使用的版本化远程 `:podspec` 安装入口仍可继续使用；不要改用 `:git` 安装。

也可以通过版本化 podspec 固定安装同一版本：

```ruby
pod 'MeshStreamKit', :podspec => 'https://raw.githubusercontent.com/Mesh-Stream/meshstream-p2p-ios-sdk/1.1.1/MeshStreamKit.podspec'
```


### 手动集成

下载 [MeshStreamKit 1.1.1](https://sdk.meshstream.net/apple/1.1.1/MeshStreamKit.zip)，解压后将 `MeshStreamKit.xcframework` 添加到 App Target，设置为 **Embed & Sign**。

版本及 SHA-256 校验信息见 [版本清单](releases/1.1.1.json)。

## 应用配置

- iOS：在 Info.plist 中设置 `NSAppTransportSecurity → NSAllowsLocalNetworking = YES`，参考 Demo。媒体源的其他 ATS 例外按业务需要配置，不建议直接放开所有网络请求。
- macOS：开启 App Sandbox 时，添加 `com.apple.security.network.client` 和 `com.apple.security.network.server` 权限。
- 后台播放、音频会话及画中画按应用需求和播放器文档配置。

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

// 由 AVPlayerLayer 或播放器控制器呈现画面。
self.player = [AVPlayer playerWithURL:self.session.playbackUrl];
[self.player play];
```

第三方播放器使用同一个 `session.playbackUrl`。如需预加载，可选调用 `[session preload]`；不调用也可正常播放。

切换视频或离开播放页时，先暂停播放器并解除其对旧播放 Item 的引用，再调用 `[session close]`。应用不再使用 SDK 时，可调用 `[P2PSDK shutdown]` 关闭所有 SDK 客户端。

## 运行 Demo

```bash
git clone https://github.com/Mesh-Stream/meshstream-p2p-ios-sdk.git
cd meshstream-p2p-ios-sdk
```

**iOS：** 打开 [`Examples/iOS/MeshStreamKitDemo.xcodeproj`](Examples/iOS/MeshStreamKitDemo.xcodeproj)，等待 Xcode 解析 SPM 依赖，选择模拟器或自己的签名 Team、Bundle ID 和真机后运行。在 Demo 中输入对应 Key 和媒体地址，再开始播放。

**macOS：** 在 Mac 上执行：

```bash
cd Examples/macOS
swift run MeshStreamKitMacDemo
```

在窗口中填写 macOS Key 和媒体地址。示例使用 AVPlayer，首次测试建议使用 HLS。窗口同时展示 Peer 与上下行流量。

## 诊断日志

日志默认关闭。如需排查问题，在创建客户端前配置：

```objc
config.logLevel = P2PLogLevelInfo;
config.fileLoggingEnabled = YES;
```

文件日志保存在应用的 Caches 目录中，支持滚动清理，不自动上传。生产环境建议按需启用；提交诊断资料前，请移除 SDK Key、访问凭据及敏感播放地址。

## 确认 P2P 生效

1. 在两台设备或两个可同时运行的实例中，用各自有效的 Key 播放同一内容，保持相同清晰度和相近播放进度。签名 URL 会变化时，为同一内容使用相同、稳定的内容 ID；不同内容不要共用 ID。
2. 查看 Demo 的 Peer 数和流量统计。Peer 大于 0 表示已连接节点；**P2P 下载或上传字节持续增加**才说明发生了媒体共享。
3. 关闭另一个实例，确认剩余实例仍能通过 HTTP/CDN 播放；然后测试拖动、切换内容和退出页面的释放流程。

只有一个观看者或没有可共享分片时，主要走 HTTP/CDN 属于正常情况。发现 Peer 及实际共享还取决于账户配置、网络连通性和双方缓存内容。

## 更多用法与支持

预加载、直播/点播调度、播放器状态回传、多会话及诊断，请参阅[高级用法](https://meshstream.net/zh/docs/sdk/ios-advanced/)。更新记录见 [CHANGELOG](CHANGELOG.md)。接入问题请联系 support@meshstream.net，并附 SDK 版本、系统、播放器和脱敏日志。

## 商业授权

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
