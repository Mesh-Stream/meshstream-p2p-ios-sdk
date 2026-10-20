Pod::Spec.new do |s|
  s.name = 'MeshStreamKit'
  s.version = '1.0.2'
  s.summary = 'P2P media delivery with streaming CDN fallback for iOS and macOS.'
  s.description = 'Commercial video delivery SDK for iOS and macOS with Objective-C APIs, AVPlayer integration, compatible third-party player support, and transfer statistics.'
  s.homepage = 'https://github.com/Mesh-Stream/meshstream-p2p-ios-sdk'
  s.author = { 'MeshStream' => 'meshstreamsupport@gmail.com' }
  s.license = { :type => 'Proprietary', :text => 'MeshStreamKit is proprietary software. Use is governed by your applicable agreement with MeshStream. Third-party components retain their respective licenses.' }
  s.source = {
    :http => 'https://sdk.meshstream.net/apple/1.0.2/MeshStreamKit.zip',
    :sha256 => '3cc6edd0fd3bbd4f1edc507c5c86d7634d92cb6291f75b777686b03445e51d35'
  }
  s.platforms = { :ios => '13.0', :osx => '10.14' }
  s.vendored_frameworks = 'MeshStreamKit.xcframework'
  s.frameworks = 'Foundation', 'Network', 'Security'
  s.requires_arc = true
end
