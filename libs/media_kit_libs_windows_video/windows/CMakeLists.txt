# libmpv for media_kit on Windows, built by package-media from pinned sources
# (tool/build_mpv.sh windows-x86_64, under MSYS2 with MinGW-w64) and linked to
# package-ffmpeg's FFmpeg DLLs, which openplayx_ffmpeg bundles: the app has
# one FFmpeg. media_kit_video links <build>/libmpv and <build>/ANGLE; ANGLE
# (OpenGL ES on Direct3D, unrelated to FFmpeg) is media_kit's pinned build.
cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "media_kit_libs_windows_video")
project(${PROJECT_NAME} LANGUAGES CXX)
set(PLUGIN_NAME "${PROJECT_NAME}_plugin")
get_filename_component(OPX_LIBS_DIR "${CMAKE_CURRENT_SOURCE_DIR}" REALPATH)
get_filename_component(OPX_MEDIA_ROOT "${OPX_LIBS_DIR}/../../.." ABSOLUTE)
set(OPX_MPV_PREFIX "${OPX_MEDIA_ROOT}/third_party/mpv/windows-x86_64")
# tool/build_mpv.sh windows-x86_64 stages libmpv here, inside this package:
# Flutter reaches plugins through .plugin_symlinks, so a path relative to the
# package-media checkout is not reliable from this directory.
set(OPX_MPV_STAGED "${CMAKE_CURRENT_SOURCE_DIR}/libmpv")

# libmpv for Windows is used when built (package-media's CI builds it before
# flutter build) or when OPX_MPV_WINDOWS=1 asks to build it here. Otherwise
# media_kit_video builds a stub and the engine router plays with libVLC.
if(EXISTS "${OPX_MPV_STAGED}/libmpv-2.dll")
  set(OPX_MPV_DIR "${OPX_MPV_STAGED}")
elseif(EXISTS "${OPX_MPV_PREFIX}/media_kit/libmpv-2.dll" OR "$ENV{OPX_MPV_WINDOWS}" STREQUAL "1")
  set(OPX_MPV_DIR "${OPX_MPV_PREFIX}/media_kit")
endif()
if(OPX_MPV_DIR)
  set(OPX_MPV_WINDOWS ON)
else()
  set(OPX_MPV_WINDOWS OFF)
endif()
message(STATUS "media_kit_libs_windows_video: libmpv ${OPX_MPV_WINDOWS} (${OPX_MPV_DIR})")
# Read by media_kit_video: without it, it builds a stub.
set(MEDIA_KIT_LIBS_AVAILABLE ${OPX_MPV_WINDOWS} CACHE BOOL "package:media_kit libraries are available." FORCE)

add_library(${PLUGIN_NAME} SHARED
  "include/media_kit_libs_windows_video/media_kit_libs_windows_video_plugin_c_api.h"
  "media_kit_libs_windows_video_plugin_c_api.cpp")
apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)

if(NOT OPX_MPV_WINDOWS)
  set(media_kit_libs_windows_video_bundled_libraries "" PARENT_SCOPE)
  return()
endif()

# libmpv: built by the CI before flutter build (like package-ffmpeg), or here.
if(NOT EXISTS "${OPX_MPV_DIR}/libmpv-2.dll")
  set(OPX_MSYS_BASH "C:/msys64/usr/bin/bash.exe")
  if(NOT EXISTS "${OPX_MSYS_BASH}")
    message(FATAL_ERROR "MSYS2 (C:/msys64) is required to build libmpv")
  endif()
  execute_process(
    COMMAND "${OPX_MSYS_BASH}" -lc "export PATH=/mingw64/bin:/usr/bin:$PATH; cd \"$(cygpath -u '${OPX_MEDIA_ROOT}')\" && bash tool/build_mpv.sh windows-x86_64"
    RESULT_VARIABLE OPX_MPV_RESULT)
  if(NOT OPX_MPV_RESULT EQUAL 0)
    message(FATAL_ERROR "Building libmpv failed (package-media tool/build_mpv.sh windows-x86_64)")
  endif()
endif()
set(LIBMPV_SRC "${CMAKE_BINARY_DIR}/libmpv")
file(REMOVE_RECURSE "${LIBMPV_SRC}")
file(COPY "${OPX_MPV_DIR}/" DESTINATION "${LIBMPV_SRC}")

# ANGLE, pinned (media_kit's release asset, verified by SHA-256).
set(ANGLE_URL "https://github.com/alexmercerind/flutter-windows-ANGLE-OpenGL-ES/releases/download/v1.0.1/ANGLE.7z")
set(ANGLE_SHA256 "cc5911bb15d596fd5a2b362613ad35b7093b427117269a7359054a65746a5f9a")
set(ANGLE_ARCHIVE "${CMAKE_BINARY_DIR}/ANGLE.7z")
set(ANGLE_SRC "${CMAKE_BINARY_DIR}/ANGLE")
if(NOT EXISTS "${ANGLE_SRC}/libEGL.dll")
  file(DOWNLOAD "${ANGLE_URL}" "${ANGLE_ARCHIVE}" EXPECTED_HASH SHA256=${ANGLE_SHA256} TLS_VERIFY ON)
  file(MAKE_DIRECTORY "${ANGLE_SRC}")
  execute_process(COMMAND "${CMAKE_COMMAND}" -E tar xf "${ANGLE_ARCHIVE}" WORKING_DIRECTORY "${ANGLE_SRC}"
    RESULT_VARIABLE OPX_ANGLE_RESULT)
  if(NOT OPX_ANGLE_RESULT EQUAL 0)
    message(FATAL_ERROR "Extracting ANGLE failed")
  endif()
endif()

set(media_kit_libs_windows_video_bundled_libraries
  "${LIBMPV_SRC}/libmpv-2.dll"
  "${ANGLE_SRC}/d3dcompiler_47.dll"
  "${ANGLE_SRC}/libEGL.dll"
  "${ANGLE_SRC}/libGLESv2.dll"
  "${ANGLE_SRC}/vk_swiftshader.dll"
  "${ANGLE_SRC}/vulkan-1.dll"
  "${ANGLE_SRC}/zlib.dll"
  PARENT_SCOPE)
