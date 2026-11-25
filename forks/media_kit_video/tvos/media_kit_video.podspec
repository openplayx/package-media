# OpenPlayX: media_kit_video on Apple TV (flutter-tvos), ported from ios/.
# Links Mpv.framework from package-media's libs/media_kit_libs_tvos_video.
Pod::Spec.new do |s|
  system("make -C ../common/darwin HEADERS_DESTDIR=\"$(pwd)/Headers\"")
  s.name             = 'media_kit_video'
  s.version          = '0.0.1'
  s.summary          = 'Native implementation for video playback in package:media_kit (Apple TV)'
  s.homepage         = 'https://github.com/openplayx/package-media'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Hitesh Kumar Saini' => 'saini123hitesh@gmail.com' }
  s.source           = { :path => '.' }
  s.platform         = :tvos, '15.0'
  s.swift_version    = '5.0'
  s.source_files     = 'Classes/plugin/**/*.swift', 'Headers/**/*.h'
  # flutter-tvos references plugins by path (no .symlinks); the libs package
  # sits in the same package-media checkout.
  libs = File.expand_path('../../../libs/media_kit_libs_tvos_video/tvos/Frameworks/.symlinks/mpv', File.realpath(__dir__))
  s.pod_target_xcconfig = {
    'DEFINES_MODULE'                                 => 'YES',
    'GCC_WARN_INHIBIT_ALL_WARNINGS'                  => 'YES',
    'GCC_PREPROCESSOR_DEFINITIONS'                   => '"$(inherited)" GL_SILENCE_DEPRECATION COREVIDEO_SILENCE_GL_DEPRECATION',
    'FRAMEWORK_SEARCH_PATHS'                         => '$(inherited) "${PODS_ROOT}/../Flutter"',
    'FRAMEWORK_SEARCH_PATHS[sdk=appletvos*]'         => "$(inherited) \"${PODS_ROOT}/../Flutter\" \"#{libs}/tvos\"",
    'FRAMEWORK_SEARCH_PATHS[sdk=appletvsimulator*]'  => "$(inherited) \"${PODS_ROOT}/../Flutter\" \"#{libs}/tvos-simulator\"",
    'OTHER_LDFLAGS'                                  => '"$(inherited)" -framework Mpv',
  }
end
