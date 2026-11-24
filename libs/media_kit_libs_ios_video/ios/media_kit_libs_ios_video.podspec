# libmpv for media_kit on iOS, built by package-media from pinned sources
# (tool/build_mpv.sh) and linked to package-ffmpeg's FFmpeg frameworks, which
# openplayx_ffmpeg vendors: the app embeds one FFmpeg. Built at `pod install`
# because CocoaPods integrates only frameworks that exist.
# Flutter loads plugins through symlinks: resolve the real checkout.
root = File.expand_path('../../..', File.realpath(__dir__))
system('bash', File.join(root, 'tool', 'ensure_mpv_apple.sh'), 'ios') ||
  raise('Building libmpv for iOS failed (package-media tool/ensure_mpv_apple.sh ios)')

Pod::Spec.new do |s|
  s.name             = 'media_kit_libs_ios_video'
  s.version          = '1.1.4'
  s.summary          = 'libmpv for package:media_kit, built by OpenPlayX package-media'
  s.homepage         = 'https://github.com/openplayx/package-media'
  s.license          = { :type => 'GPL-2.0-or-later' }
  s.author           = 'OpenPlayX'
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.vendored_frameworks = 'Frameworks/Mpv.xcframework'
  s.platform = :ios, '15.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
