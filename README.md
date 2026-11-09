# MeshStreamKit: P2P SDK for iOS and macOS

[简体中文](README.zh-CN.md) · [Website](https://meshstream.net/) · [Documentation](https://meshstream.net/docs/sdk/ios-setup/) · [CocoaPods](https://cocoapods.org/pods/MeshStreamKit) · [Live demo](https://demo.meshstream.net/)

MeshStreamKit is a P2P video and audio streaming SDK for iOS and macOS apps built with Swift or Objective-C. It provides a local playback URL for AVPlayer or another URL-capable player, adds peer-assisted delivery when available, and falls back to HTTP/CDN delivery.

Current release: `1.0.10`.

## How it works

Create a session from your media URL, then give its `playbackUrl` to your existing player:

```text
App → SDK playback session → Local playback URL → Player
                              └─ SDK fetches from peers or origin/CDN
```

Your player handles decoding, rendering and playback controls. The SDK handles media delivery, caching and P2P scheduling. Configuration and P2P preparation run in the background; playback need not wait for a peer connection. Stop using the old playback URL before closing its session when leaving the page or switching content.

## Features

- HLS, MPEG-DASH and HTTP Range MP4/MP3 delivery through a shared session API.
- Swift and Objective-C integration with AVPlayer or another compatible player.
- Preload, per-session traffic counters, peer events and diagnostics.
- Swift Package Manager and CocoaPods; iOS device, universal iOS simulator and universal macOS components.

## Before you start

- Create an application and a platform-specific SDK Key in the [MeshStream console](https://console.meshstream.net/). If application identity validation is enabled, register the package name or Bundle ID of the app you run.
- Have a playable HLS `.m3u8`, DASH `.mpd`, or HTTP Range-capable MP4 / MP3 URL. Prefer HTTPS.
- Choose a player that supports your source format. The SDK adds delivery capabilities, not codecs; AVPlayer, for example, does not natively play DASH.

To try it first, jump to [Run the demo](#run-the-demo). The online demo linked above is a Web experience; run this repository's example for this platform.

## Requirements

| Platform | Minimum supported version |
| --- | --- |
| iOS device | iOS 15 |
| iOS simulator | iOS 15 on Intel, iOS 15 on Apple Silicon |
| macOS | macOS 12 on Intel, macOS 12 on Apple Silicon |

The release contains device and simulator slices for iOS plus x86_64 and
arm64 slices for macOS.

## Install

### Swift Package Manager

In Xcode, choose **File → Add Package Dependencies**, enter the package URL,
select **Exact Version: 1.0.10**, and add the `MeshStreamKit` product to your app target:

```text
https://github.com/Mesh-Stream/meshstream-p2p-ios-sdk.git
```

### CocoaPods

```ruby
pod 'MeshStreamKit', '1.0.10'
```

Run `pod install` after updating your Podfile.

Choose one installation method per app target. SPM requires a toolchain supporting Swift Tools 5.9. After CocoaPods installation, open the generated `.xcworkspace`.

For manual installation, download [MeshStreamKit 1.0.10](https://sdk.meshstream.net/apple/1.0.10/MeshStreamKit.zip), add `MeshStreamKit.xcframework` to the app target and select **Embed & Sign**. The [release record](releases/1.0.10.json) contains its SHA-256.

## Application configuration

- For iOS, set `NSAllowsLocalNetworking = YES` under
  `NSAppTransportSecurity` in `Info.plist`; retain only the additional ATS
  exceptions required by your media origin.
- For sandboxed macOS apps, enable
  `com.apple.security.network.client` and
  `com.apple.security.network.server`.
- Diagnostics logging is disabled by default. Enable it only for
  troubleshooting and remove SDK Keys, credentials, and signed URLs from any
  shared diagnostic material.

## Start playback

This Objective-C example uses AVPlayer. `mediaURL` is your source `NSURL`; retain `client`, `session` and `player` as properties of your view controller or playback owner. Add an `AVPlayerLayer` or player view controller to display video.

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

Keep the session alive while the player uses `session.playbackUrl`. Preload is optional: call `[session preload]` before giving the URL to the player.

When switching media or leaving the page, pause the player, detach its item, then close the session:

```objc
[self.player pause];
[self.player replaceCurrentItemWithPlayerItem:nil];
[self.session close];
```

Call `[P2PSDK shutdown]` only when the application no longer uses any SDK client.

## Run the demo

```bash
git clone https://github.com/Mesh-Stream/meshstream-p2p-ios-sdk.git
cd meshstream-p2p-ios-sdk
```

**iOS:** Open [`Examples/iOS/MeshStreamKitDemo.xcodeproj`](Examples/iOS/MeshStreamKitDemo.xcodeproj), let Xcode resolve the SPM dependency, then select a simulator or configure your signing team and Bundle ID for a device. Run the app, enter the matching Key and media URL, and start playback.

**macOS:** On a Mac, run:

```bash
cd Examples/macOS
swift run MeshStreamKitMacDemo
```

Enter your macOS Key and media URL in the window. The examples use AVPlayer; start with HLS. The UI also displays peers and download/upload counters.

## Diagnostics

Logging is disabled by default. For troubleshooting, set `config.logLevel = P2PLogLevelInfo` and `config.fileLoggingEnabled = YES` before creating the client. File logs rotate in the application's Caches directory and are not uploaded automatically. Redact Keys, credentials and signed URLs before sharing logs.

## Verify P2P delivery

1. Play the same content in two devices or independently running instances, each with a valid Key. Use the same rendition and nearby playback positions. For rotating signed URLs, use the same stable content ID for the same content, and different IDs for different content.
2. Watch peers and traffic in the demo. A nonzero peer count means a connection exists; **increasing P2P download or upload bytes** confirms media sharing.
3. Close the other instance and check that HTTP/CDN playback continues. Also check seeking, switching content and cleanup when leaving playback.

HTTP/CDN delivery is normal with one viewer or no shareable segments. Discovery and sharing also depend on account configuration, network connectivity and the content cached by both viewers.

## More examples and support

See [advanced usage](https://meshstream.net/docs/sdk/ios-advanced/) for preload, live/VOD scheduling, player feedback, multiple sessions and diagnostics. See [CHANGELOG](CHANGELOG.md) for updates. Contact support@meshstream.net with the SDK version, OS, player and redacted logs.

## License

MeshStreamKit is proprietary software distributed under the applicable
commercial agreement. Review [LICENSE](LICENSE) and
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). For integration, licensing,
or distribution support, contact support@meshstream.net.

## Other MeshStream SDKs

- [Web](https://github.com/Mesh-Stream/meshstream-p2p-web-sdk): JavaScript / TypeScript, WebRTC and browser players.
- [Android](https://github.com/Mesh-Stream/meshstream-p2p-android-sdk): Kotlin / Java, Maven and Media3 / ExoPlayer.
- [Windows](https://github.com/Mesh-Stream/meshstream-p2p-Windows-sdk): C / C++ API for Windows 10 / 11 x64.
- [uni-app](https://github.com/Mesh-Stream/meshstream-p2p-uniapp-sdk): UTS / JavaScript plugin for iOS and Android apps.
- [Flutter](https://github.com/Mesh-Stream/meshstream-p2p-flutter-sdk): Dart plugin for iOS / Android with video_player examples.
- [React Native](https://github.com/Mesh-Stream/meshstream-p2p-react-native-sdk): TypeScript API for iOS / Android with react-native-video examples.
