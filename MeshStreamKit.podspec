Pod::Spec.new do |s|
  s.name = 'MeshStreamKit'
  s.version = '0.1.0'
  s.summary = 'P2P media delivery with streaming CDN fallback for iOS and macOS.'
  s.description = 'Player-agnostic Objective-C SDK distributed as a binary XCFramework. Supports HLS and compatible third-party media players without requiring Rust on the customer machine.'
  s.homepage = 'https://github.com/Mesh-Stream/meshstream-p2p-ios'
  s.author = { 'MeshStream' => 'meshstreamsupport@gmail.com' }
  s.license = { :type => 'Proprietary', :text => 'MeshStreamKit is proprietary software. Use is governed by your applicable agreement with MeshStream. Third-party components retain their respective licenses.' }
  s.source = {
    :http => 'https://sdk.meshstream.net/apple/0.1.0/MeshStreamKit-r2.zip',
    :sha256 => 'a6d8889678a5a6f71480bc2cc84d7459f74b449a5c6f5492731ace9536788202'
  }
  s.platforms = { :ios => '13.0', :osx => '10.14' }
  s.vendored_frameworks = 'MeshStreamKit.xcframework'
  s.frameworks = 'Foundation', 'Network', 'Security'
  s.requires_arc = true
end
