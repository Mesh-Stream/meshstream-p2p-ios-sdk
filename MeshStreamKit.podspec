Pod::Spec.new do |s|
  s.name = 'MeshStreamKit'
  s.version = '1.1.0'
  s.summary = 'P2P media delivery with streaming CDN fallback for iOS and macOS.'
  s.description = 'Commercial video delivery SDK for iOS and macOS with Objective-C APIs, AVPlayer integration, compatible third-party player support, and transfer statistics.'
  s.homepage = 'https://github.com/Mesh-Stream/meshstream-p2p-ios-sdk'
  s.author = { 'MeshStream' => 'meshstreamsupport@gmail.com' }
  s.license = { :type => 'Proprietary', :text => 'MeshStreamKit is proprietary software. Use is governed by your applicable agreement with MeshStream. Third-party components retain their respective licenses.' }
  s.source = {
    :http => 'https://sdk.meshstream.net/apple/1.1.0/MeshStreamKit.zip',
    :sha256 => '2d06b0af34e887ff43232144c5cc10858c00d2ca339c5226a195140aa2d0fb46'
  }
  s.platforms = { :ios => '15.0', :osx => '12.0' }
  s.vendored_frameworks = 'MeshStreamKit.xcframework'
  s.frameworks = 'Foundation', 'Network', 'Security'
  s.requires_arc = true
end
