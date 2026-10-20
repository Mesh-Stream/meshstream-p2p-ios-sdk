# MeshStreamKit

[简体中文](README.zh-CN.md)

MeshStreamKit is the MeshStream media delivery SDK for iOS and macOS. It
creates a CDN-compatible playback URL and adds P2P delivery opportunistically;
your player remains responsible for rendering and playback lifecycle.

## MeshStream SDKs

- [Online Demo](https://demo.meshstream.net/) for a live Web playback and P2P delivery view.
- [Web Demo](https://github.com/Mesh-Stream/meshstream-p2p-web-sdk) using the published npm SDK.
- [Android SDK](https://github.com/Mesh-Stream/meshstream-p2p-android-sdk) for Media3 / ExoPlayer apps.
- [Apple SDK](https://github.com/Mesh-Stream/meshstream-p2p-ios-sdk) for iOS and macOS apps.
- [Windows SDK](https://github.com/Mesh-Stream/meshstream-p2p-Windows-sdk) for C/C++ desktop apps.

## Requirements

| Platform | Minimum supported version |
| --- | --- |
| iOS device | iOS 13 |
| iOS simulator | iOS 13 on Intel, iOS 14 on Apple Silicon |
| macOS | macOS 10.14 on Intel, macOS 11 on Apple Silicon |

The release contains device and simulator slices for iOS plus x86_64 and
arm64 slices for macOS.

## Install

### Swift Package Manager

In Xcode, choose **File → Add Package Dependencies**, enter the package URL,
then select the latest stable release:

```text
https://github.com/Mesh-Stream/meshstream-p2p-ios-sdk.git
```

### CocoaPods

```ruby
pod 'MeshStreamKit'
```

Run `pod install` after updating your Podfile.

## Quick integration

Create a client from the SDK Key, create one playback session for each media
item, then hand the returned URL to `AVPlayer` or another URL-capable player.

```objc
#import <AVFoundation/AVFoundation.h>
#import <MeshStreamKit/MeshStreamKit.h>

P2PConfig *config = [[P2PConfig alloc] initWithKey:@"YOUR_IOS_SDK_KEY"];
NSError *error = nil;
P2PClient *client = [P2PSDK clientWithConfig:config error:&error];
PlaybackSession *session = [client createPlaybackSessionWithURL:mediaURL error:&error];

AVPlayer *player = [AVPlayer playerWithURL:session.playbackUrl];
[player play];
```

The SDK resolves service configuration in the background. If acceleration is
unavailable, the returned playback URL continues through the configured
origin/CDN path and must remain playable.

Use a stable content identity for rotating signed URLs, if applicable. Close a
session when its player item is no longer used; call `[P2PSDK shutdown]` when
the application no longer owns any SDK client.

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

## Examples

- iOS: `Examples/iOS/MeshStreamKitDemo.xcodeproj`
- macOS: run `swift run MeshStreamKitMacDemo` in `Examples/macOS`

Examples do not include an SDK Key. Create an application and Key in the
MeshStream console before running them.

## Support

MeshStreamKit is proprietary software distributed under the applicable
commercial agreement. Review [LICENSE](LICENSE) and
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). For integration, licensing,
or distribution support, contact support@meshstream.net.
