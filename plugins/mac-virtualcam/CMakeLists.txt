cmake_minimum_required(VERSION 3.28...3.30)

option(ENABLE_VIRTUALCAM "Build OBS Virtualcam" ON)

if(NOT ENABLE_VIRTUALCAM)
  target_disable_feature(mac-virtualcam "macOS Virtual Camera support")
  return()
endif()

target_enable_feature(mac-virtualcam "macOS Virtual Camera support")

add_library(obs-mach-protocol INTERFACE)
add_library(OBS::mach-protocol ALIAS obs-mach-protocol)

target_sources(obs-mach-protocol INTERFACE src/common/MachProtocol.h src/common/data/placeholder.png)
target_include_directories(obs-mach-protocol INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/src/common")

add_subdirectory(src/obs-plugin)
add_subdirectory(src/dal-plugin)

# OBS Studio Plus: the camera-extension target is Swift-only and CMake's Swift
# support is tied to the Xcode generator. Skip it on Ninja (CLT-only) builds —
# the rest of the virtual camera (DAL plugin + obs-plugin) still works for
# legacy CMIO consumers; only the modern Camera Extension flavor is gated.
if(XCODE)
  add_subdirectory(src/camera-extension)
else()
  message(STATUS "OBS Studio Plus: skipping mac-camera-extension (requires Xcode generator).")
endif()
