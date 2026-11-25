# libmpv for media_kit on Linux, built by package-media from pinned sources
# (tool/build_mpv.sh) and linked to package-ffmpeg's shared FFmpeg, which
# openplayx_ffmpeg bundles: the app has one FFmpeg. Built at configure time;
# this plugin is configured before media_kit_video, whose pkg-config lookup of
# "mpv" then finds this build instead of a system libmpv.
cmake_minimum_required(VERSION 3.13)
set(PROJECT_NAME "media_kit_libs_linux")
project(${PROJECT_NAME} LANGUAGES CXX)
set(PLUGIN_NAME "${PROJECT_NAME}_plugin")
# Read by media_kit_video: without it, it builds a stub.
option(MEDIA_KIT_LIBS_AVAILABLE "package:media_kit libraries are available." ON)

# Flutter adds plugins through symlinks: resolve this directory first.
get_filename_component(OPX_LIBS_DIR "${CMAKE_CURRENT_SOURCE_DIR}" REALPATH)
get_filename_component(OPX_MEDIA_ROOT "${OPX_LIBS_DIR}/../../.." ABSOLUTE)
if(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm64")
  set(OPX_MPV_TARGET "linux-arm64")
else()
  set(OPX_MPV_TARGET "linux-x86_64")
endif()
execute_process(
  COMMAND bash "${OPX_MEDIA_ROOT}/tool/build_mpv.sh" "${OPX_MPV_TARGET}"
  RESULT_VARIABLE OPX_MPV_RESULT)
if(NOT OPX_MPV_RESULT EQUAL 0)
  message(FATAL_ERROR "Building libmpv failed (package-media tool/build_mpv.sh ${OPX_MPV_TARGET})")
endif()
set(OPX_MPV_PREFIX "${OPX_MEDIA_ROOT}/third_party/mpv/${OPX_MPV_TARGET}")
file(STRINGS "${OPX_MPV_PREFIX}/BUILDINFO" OPX_MPV_FFMPEG_PREFIX REGEX "^ffmpeg_prefix=")
string(REPLACE "ffmpeg_prefix=" "" OPX_MPV_FFMPEG_PREFIX "${OPX_MPV_FFMPEG_PREFIX}")
set(ENV{PKG_CONFIG_PATH} "${OPX_MPV_PREFIX}/lib/pkgconfig:${OPX_MPV_FFMPEG_PREFIX}/lib/pkgconfig:$ENV{PKG_CONFIG_PATH}")

add_library(${PLUGIN_NAME} SHARED "media_kit_libs_linux_plugin.cc")
apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter PkgConfig::GTK)

# Plugins configured after this one (media_kit_video links libmpv) find
# libmpv.so.2 and FFmpeg next to them in the bundle's lib/.
set(CMAKE_INSTALL_RPATH "$ORIGIN" PARENT_SCOPE)
set(CMAKE_BUILD_RPATH "$ORIGIN" PARENT_SCOPE)

# libmpv.so.2 (a real file named by its soname) into the bundle's lib/.
set(media_kit_libs_linux_bundled_libraries "${OPX_MPV_PREFIX}/bundle/libmpv.so.2" PARENT_SCOPE)
