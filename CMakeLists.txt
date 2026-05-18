cmake_minimum_required(VERSION 3.28...3.30)

include("${CMAKE_CURRENT_SOURCE_DIR}/cmake/common/bootstrap.cmake" NO_POLICY_SCOPE)

project(obs-studio VERSION ${OBS_VERSION_CANONICAL})

if(CMAKE_HOST_SYSTEM_NAME MATCHES "Windows")
  include("${CMAKE_CURRENT_SOURCE_DIR}/cmake/windows/architecture.cmake")
  if(NOT OBS_PARENT_ARCHITECTURE STREQUAL CMAKE_VS_PLATFORM_NAME)
    return()
  endif()
endif()

include(compilerconfig)
include(defaults)
include(helpers)

option(ENABLE_UI "Enable building with UI (requires Qt)" ON)
option(ENABLE_SCRIPTING "Enable scripting support" ON)
option(ENABLE_HEVC "Enable HEVC encoders" ON)

add_subdirectory(libobs)
if(OS_WINDOWS)
  add_subdirectory(libobs-d3d11)
  add_subdirectory(libobs-winrt)
endif()
add_subdirectory(libobs-opengl)
if(OS_MACOS)
  # OBS Studio Plus: libobs-metal is Swift-only and CMake's Swift support is
  # tied to the Xcode generator. CLT-only Ninja builds fall back to the
  # OpenGL renderer (still fully functional, just not the modern Metal path).
  if(XCODE)
    add_subdirectory(libobs-metal)
  else()
    message(STATUS "OBS Studio Plus: skipping libobs-metal (Swift requires Xcode generator); using OpenGL renderer.")
  endif()
endif()
add_subdirectory(plugins)

add_subdirectory(test/test-input)

add_subdirectory(frontend)

message_configuration()
