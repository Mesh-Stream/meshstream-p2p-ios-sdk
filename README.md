# MeshStreamKit for iOS and macOS

MeshStreamKit 是播放器无关的 P2P 媒体分发 SDK，使用 Objective-C API，内部二进制已包含 Rust Core 和原生依赖。客户无需安装 Rust，也无需配置 Bootstrap 服务。

此仓库提供安装入口、Demo 和版本说明；SDK 二进制由 Cloudflare R2 分发，不包含内部实现源码。

当前版本：`0.1.0`。

## Swift Package Manager（推荐）

Xcode → File → Add Package Dependencies，输入：

```text
https://github.com/Mesh-Stream/meshstream-p2p-ios
```

选择版本 `0.1.0`，添加 `MeshStreamKit` 产品。Objective-C 工程也可以使用 SPM 安装，无需改成 Swift。

## CocoaPods

当前提供版本化远程 podspec，尚未声明已发布到 CocoaPods Trunk：

```ruby
platform :ios, '13.0'

target 'YourApp' do
  pod 'MeshStreamKit', :podspec => 'https://raw.githubusercontent.com/Mesh-Stream/meshstream-p2p-ios/0.1.0/MeshStreamKit.podspec'
end
```

macOS 工程使用 `platform :osx, '10.14'`。执行 `pod install` 后打开生成的 `.xcworkspace`。

不要用 `:git` 指向本仓库安装二进制：本仓库不保存 XCFramework，远程 podspec 的 `source` 才会下载 Cloudflare ZIP。

## 手动集成

下载 [MeshStreamKit.zip](https://sdk.meshstream.net/apple/0.1.0/MeshStreamKit-r2.zip)，解压后将 `MeshStreamKit.xcframework` 加入 App Target，设置为 **Embed & Sign**。不要在同一个 Target 混用手动、SPM、CocoaPods 三种安装方式。

校验值见 [release manifest](releases/0.1.0.json)。每个版本的 URL 和 ZIP 保持不可变。

## 播放示例

```objc
#import <AVFoundation/AVFoundation.h>
#import <MeshStreamKit/MeshStreamKit.h>

// client、session、player 需要由页面或播放管理器持有。
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

媒体数据通过本机 HTTP 代理流式转发；Bootstrap、Token 和 P2P 连接在后台处理，不需要业务层等待它们完成后再播放。`[session preload]` 是可选预加载接口，不调用也可正常播放。

替换媒体或离开播放页时，先暂停并解除播放器对旧 Item 的引用，再调用 `[session close]`。需要关闭 SDK 的所有客户端时调用 `[P2PSDK shutdown]`。

第三方播放器同样使用 `session.playbackUrl`；是否支持 DASH、DRM、解码格式取决于播放器。AVPlayer 不会因接入 SDK 而获得 DASH 支持。

## Demo

- iOS：打开 `Examples/iOS/MeshStreamKitDemo.xcodeproj`，选择自己的签名 Team、Bundle ID，填入该应用的 SDK Key。项目通过本地 SPM 清单从 Cloudflare 下载 SDK。
- macOS：在 `Examples/macOS` 执行 `swift run MeshStreamKitMacDemo`，填入对应应用的 SDK Key。
- SDK Key 需与控制台登记的应用及 Bundle ID 匹配。仓库不内置客户 SDK Key。

## 系统与网络配置

- iOS 真机：iOS 13+；模拟器：Intel iOS 13+、Apple Silicon iOS 14+。
- macOS：Intel macOS 10.14+、Apple Silicon macOS 11+。
- SPM 清单要求 Swift Tools 5.9+；SDK 的公共 API 仍为 Objective-C。
- iOS 本地代理集成请配置 `NSAppTransportSecurity → NSAllowsLocalNetworking = YES`，参考 Demo 的 `Info.plist`。媒体源自身的 ATS 例外应按业务需要最小化配置。
- 开启 macOS App Sandbox 时，媒体下载需要 `com.apple.security.network.client`；本机代理监听需要 `com.apple.security.network.server`。

## 日志

```objc
config.logLevel = P2PLogLevelInfo;
config.fileLoggingEnabled = YES; // 可选，默认关闭；在创建 client 之前设置
```

日志默认关闭。启用文件日志后，SDK 在应用 Caches/meshstream/logs 中轮转保存 `meshstream01.log` 至 `meshstream03.log`，每个最多 2 MiB，不自动上传。生产环境应按需开启，不要输出 SDK Key、Token 或签名 URL。

## 发布与支持

版本变更见 [CHANGELOG](CHANGELOG.md)。SDK 为专有软件，使用需遵循适用协议。第三方组件说明见 [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES.md)。App Store 发布前，集成方仍需按实际使用方式核对隐私披露、签名及权限要求。

支持邮箱：meshstreamsupport@gmail.com。
