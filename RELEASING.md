# Apple SDK 发布约定与换机手册

本文记录已采用的发布方式，供维护者在其他 Mac 上更新 SDK。客户安装步骤见 [README](README.md)。

## 1. 固定约定

| 项目 | 约定 |
| --- | --- |
| 公开分发仓库 | `https://github.com/Mesh-Stream/meshstream-p2p-ios-sdk.git` |
| 发布分支 | `main` |
| 版本标签 | 语义化版本，不加 `v`，例如 `0.1.0` |
| SDK 名称 | `MeshStreamKit`，动态 `MeshStreamKit.xcframework` |
| 二进制存储 | Cloudflare R2 bucket：`meshstream-sdks` |
| 公开下载域名 | `https://sdk.meshstream.net` |
| 新版本对象路径 | `apple/<version>/MeshStreamKit.zip` |
| 安装方式 | SPM binary target / CocoaPods 远程 podspec / 手动下载 |

公开仓库只存安装清单、版本元数据、Demo、文档和许可证，不放内部 Rust/Objective-C 实现源码、SDK Key、签名信息、凭据或编译缓存。SPM 和 CocoaPods 必须引用同一份 ZIP 和同一个 SHA-256。

已发布 ZIP、Git 标签和版本元数据均不可覆盖。新功能或修复发布新版本；即使二进制代码未改，公开版本的打包修复也发布新版本。失败版本通过新版本替代，不重写历史标签。

`0.1.0` 的首次发布在标签公开前完成过打包修订，实际使用 `MeshStreamKit-r2.zip`；这是历史对象名，不要改回无后缀 URL，也不要使用早期的 `MeshStreamKit.zip`。

## 2. 新 Mac 准备

1. 安装完整 Xcode 并完成首次启动及许可确认，选择正确的开发工具目录；准备 Git、Node.js、GitHub CLI、Rust/rustup、CMake、CocoaPods。SPM 使用 Xcode 自带 Swift，Swift Tools 至少 5.9。
2. 登录有仓库写入权限的 GitHub 账号、有 R2 对象写入权限的 Cloudflare 账号。凭据只保存在系统钥匙串或 CLI 的私有配置中，不能复制进仓库或聊天。

```sh
gh auth login
gh auth setup-git
gh auth status
npx wrangler@4 login
npx wrangler@4 whoami
```

3. 克隆分发仓库和另行授权的内部源码仓库；不要从旧电脑复制 `.runtime`、`DerivedData`、`.build` 或钥匙串文件。

```sh
git clone https://github.com/Mesh-Stream/meshstream-p2p-ios-sdk.git
cd meshstream-p2p-ios-sdk
git switch main
git pull --ff-only
git fetch --tags
gh api repos/Mesh-Stream/meshstream-p2p-ios-sdk --jq '.permissions.push'
```

最后一条必须为 `true`。不要为换电脑重新建 bucket、重新绑定域名或修改现有 Android bucket `meshstream-maven`。内部源码仓库位置、Cloudflare account ID 和构建注意事项见内部发布文档。

网络需要代理时，按新电脑实际端口临时配置 `HTTPS_PROXY` / `HTTP_PROXY`，Git 可用单次 `-c http.proxy=...`；不要硬编码旧电脑的代理端口，也不要为了发布修改全局代理。

## 3. 编译、打包

在内部源码仓库执行，以下以尚未发布的 `0.1.1` 为例。发布前确认该版本在 Git 标签和 R2 均不存在；不要直接重复上传这些示例路径。

```sh
export MESHSTREAM_VERSION=0.1.1
git status --short
git submodule update --init --recursive
rustup target add aarch64-apple-darwin x86_64-apple-darwin aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios
P2PCDN_MACOS_TARGETS='aarch64-apple-darwin x86_64-apple-darwin' \
  bash sdks/apple/scripts/package_sdk.sh --version "$MESHSTREAM_VERSION" --include-ios
git rev-parse HEAD
```

不要使用默认仅包含宿主 macOS 架构的构建参数发布通用包。源码及依赖版本必须可追溯，不能把未记录的工作区修改宣称为某个干净 commit 的构建。

输出位于 `sdks/apple/dist/`：ZIP、`.zip.sha256`、JSON。压缩包根目录必须是 `MeshStreamKit.xcframework/`，并检查：

- iOS device：arm64；iOS simulator：arm64 + x86_64；macOS：arm64 + x86_64。
- macOS framework 必须采用 `Versions/A/Resources/Info.plist` 的版本化目录及有效符号链接，不能直接套用 iOS 的浅目录结构。否则 CocoaPods/Xcode 嵌入可能失败。
- 系统下限不能仅看 SPM 声明：iOS arm64 / Intel simulator 为 13+，Apple Silicon simulator 为 14+；Intel macOS 为 10.14+，Apple Silicon macOS 为 11+。后续调整需同步实际 Mach-O、清单及 README。
- 更新第三方依赖后同步许可证与第三方声明；本地打包 JSON 不是公开 release manifest 的直接替代品。

## 4. 上传 R2，更新清单

先查看 Cloudflare 控制台，确认目标对象路径不存在。`r2 object put` 可以覆盖已有对象，不自带不可变保护；存在时必须停止并换新版本。

在源码仓库中上传已验证的新 ZIP：

```sh
export MESHSTREAM_ZIP="$PWD/sdks/apple/dist/meshstreamkit-apple-sdk-$MESHSTREAM_VERSION.zip"
npx wrangler@4 r2 object put "meshstream-sdks/apple/$MESHSTREAM_VERSION/MeshStreamKit.zip" \
  --remote --file "$MESHSTREAM_ZIP" --content-type application/zip \
  --cache-control 'public, max-age=31536000, immutable'
shasum -a 256 "$MESHSTREAM_ZIP"
```

在公开仓库中修改并审查：

- `Package.swift`：binary target 的 URL、checksum。
- `MeshStreamKit.podspec`：version、HTTP URL、SHA-256、平台要求。
- `releases/<version>.json`：version、URL、sha256、sourceRevision、构建日期、架构、系统下限及打包修订信息，参考现有 manifest；原始 manifest 不变。
- `README.md`、`CHANGELOG.md`：版本、下载和远程 podspec 链接。
- `Tests/distribution.test.mjs`：随当前发布版本更新 manifest 路径，不能一直验证旧版本。
- 如 API、依赖、Demo 有变化，同步 Demo、许可证及第三方声明，移除实际 Key 和本机签名 Team。

将同一公开 manifest 上传到该版本的 `manifest.json`（`application/json`），将打包脚本生成的 `.zip.sha256` 上传到 `MeshStreamKit.zip.sha256`（`text/plain`）；都使用 `--remote` 及同样的 immutable 缓存策略。校验文件中的 ZIP 名是本地构建文件名，远程对象名可以不同，以 SHA-256 为准。

CocoaPods 继续用版本化远程 podspec：

```ruby
pod 'MeshStreamKit', :podspec => 'https://raw.githubusercontent.com/Mesh-Stream/meshstream-p2p-ios-sdk/0.1.1/MeshStreamKit.podspec'
```

不要改为 `:git`：Git 仓库没有 XCFramework，CocoaPods 的 Git 外部源会覆盖 podspec 的 HTTP 下载源。当前没有发布到 CocoaPods Trunk，不能只写 `pod 'MeshStreamKit', '0.1.1'` 并声称可用。

## 5. 校验与发布

在公开仓库执行，`MESHSTREAM_SDK_ZIP` 需设为新电脑上的实际 ZIP 绝对路径：

```sh
MESHSTREAM_SDK_ZIP="$MESHSTREAM_ZIP" node --test Tests/distribution.test.mjs
pod spec lint MeshStreamKit.podspec --verbose
swift build --package-path Examples/macOS
xcodebuild -project Examples/iOS/MeshStreamKitDemo.xcodeproj \
  -scheme MeshStreamKitDemo -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/meshstream-public-ios-verification \
  CODE_SIGNING_ALLOWED=NO build
git diff --check
git status --short
```

必须读取各条命令的退出码和完整结果。仅通过清单测试不代表 Demo 构建成功；lint 不能用跳过导入或忽略告警来掩盖包格式问题。还应从公网实际下载 ZIP，确认其 SHA-256 与本地及两份清单一致。

审查并暂存本次发布需要的文件后提交；不要无差别暂存缓存、密钥或内部实现文件。以下命令在公开仓库执行，标签只能新建，不得 `-f`：

```sh
git commit -m "release: MeshStreamKit $MESHSTREAM_VERSION"
git tag -a "$MESHSTREAM_VERSION" -m "MeshStreamKit $MESHSTREAM_VERSION"
git push --dry-run --atomic origin main "refs/tags/$MESHSTREAM_VERSION"
git push --atomic origin main "refs/tags/$MESHSTREAM_VERSION"
git ls-remote origin refs/heads/main "refs/tags/$MESHSTREAM_VERSION" "refs/tags/$MESHSTREAM_VERSION^{}"
```

先验证 R2 下载，再发布 Git 引用，避免客户获得指向不存在 ZIP 的安装清单。发布后核对远程分支和标签提交、公开版本化 podspec 和 Package.swift，并用该 Git 标签做一次独立集成验证。GitHub Release 页面是可选展示，不是 SPM 的前提；版本标签才是安装依据。

仅更新文档可以直接提交 `main`，不能因此移动旧版本标签。

## 6. 历史基线与故障处理

首次公开版本 `0.1.0`：

- ZIP：`https://sdk.meshstream.net/apple/0.1.0/MeshStreamKit-r2.zip`
- SHA-256：`a6d8889678a5a6f71480bc2cc84d7459f74b449a5c6f5492731ace9536788202`
- R2 manifest：`apple/0.1.0/manifest-r2.json`。
- Git 发布提交：`88a4571e802a2ff3204b33ef67a715584c7fbee8`。
- SDK 源码及架构明细见 [版本 manifest](releases/0.1.0.json)。

GitHub 403：先确认 `gh auth status` 和 `.permissions.push`，再检查 Git 是否仍使用旧钥匙串身份；可重新执行 `gh auth setup-git`，不要把 Token 放进 URL。Cloudflare 401/403：确认当前账号、目标 account 和 R2 写权限。校验值不一致：立即停止发布，不能改客户端 checksum 去适配来源不明的 ZIP。已公开版本失败时保留历史对象，按新版本修复。
