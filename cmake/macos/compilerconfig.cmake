# OBS CMake macOS compiler configuration module

include_guard(GLOBAL)

option(ENABLE_COMPILER_TRACE "Enable clang time-trace" OFF)
mark_as_advanced(ENABLE_COMPILER_TRACE)

# OBS Studio Plus: allow non-Xcode generators on macOS.
# Upstream OBS hard-requires Xcode.app for codesigning + .app bundle layout. The
# fork supports the Ninja generator with Command Line Tools alone for the
# common case of local development builds. Distribution-grade builds (universal
# binaries, dSYM bundles, full codesign) still need Xcode and use the upstream
# `macos` preset.
if(NOT XCODE)
  set(OBS_PLUS_NON_XCODE_BUILD TRUE)
  message(STATUS "OBS Studio Plus: building without Xcode generator (CLT-only mode).")
  # Xcode auto-detects .m/.mm files and switches to the Objective-C compiler.
  # Ninja and other generators don't — they treat .m as plain C unless OBJC /
  # OBJCXX are explicitly enabled at project scope.
  enable_language(OBJC)
  enable_language(OBJCXX)
endif()

include(compiler_common)

add_compile_options("$<$<NOT:$<COMPILE_LANGUAGE:Swift>>:-fopenmp-simd>")

# OBS Studio Plus: enable Clang modules globally for ObjC sources (cheap,
# universally compatible). ARC must NOT be enabled globally because libobs-opengl
# uses manual retain/release. Use obs_plus_target_apply_arc() to enable ARC
# per-target for those that opted in via XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC.
if(OBS_PLUS_NON_XCODE_BUILD)
  add_compile_options(
    "$<$<COMPILE_LANGUAGE:OBJC>:-fmodules>"
    "$<$<COMPILE_LANGUAGE:OBJCXX>:-fmodules>"
  )
endif()

# Helper called by Mac targets that previously relied on Xcode to enable ARC.
function(obs_plus_target_apply_arc TARGET)
  if(NOT OBS_PLUS_NON_XCODE_BUILD)
    return()
  endif()
  target_compile_options(
    ${TARGET}
    PRIVATE "$<$<COMPILE_LANGUAGE:OBJC>:-fobjc-arc>"
            "$<$<COMPILE_LANGUAGE:OBJCXX>:-fobjc-arc>"
  )
endfunction()

if(CMAKE_CXX_STANDARD GREATER_EQUAL 20)
  add_compile_options($<$<COMPILE_LANGUAGE:CXX>:-fno-char8_t>)
endif()

# Ensure recent enough Xcode and platform SDK
function(check_sdk_requirements)
  set(obs_macos_minimum_sdk 15.0) # Keep in sync with Xcode
  set(obs_macos_minimum_xcode 16.0) # Keep in sync with SDK

  # OBS Studio Plus: in CLT-only mode, --show-sdk-platform-version isn't
  # populated, but --show-sdk-version returns the same effective version
  # (e.g. 26.5). Fall back to it so the SDK floor still gets enforced.
  set(_sdk_version_args --show-sdk-platform-version)
  if(OBS_PLUS_NON_XCODE_BUILD)
    set(_sdk_version_args --show-sdk-version)
  endif()

  execute_process(
    COMMAND xcrun --sdk macosx ${_sdk_version_args}
    OUTPUT_VARIABLE obs_macos_current_sdk
    RESULT_VARIABLE result
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )
  if(NOT result EQUAL 0)
    message(
      FATAL_ERROR
      "Failed to fetch macOS SDK version. "
      "Ensure that the macOS SDK is installed and that xcode-select points at the Xcode developer directory."
    )
  endif()
  message(DEBUG "macOS SDK version: ${obs_macos_current_sdk}")
  if(obs_macos_current_sdk VERSION_LESS obs_macos_minimum_sdk)
    message(
      FATAL_ERROR
      "Your macOS SDK version (${obs_macos_current_sdk}) is too low. "
      "The macOS ${obs_macos_minimum_sdk} SDK (Xcode ${obs_macos_minimum_xcode}) is required to build OBS."
    )
  endif()

  # OBS Studio Plus: the xcodebuild + XCODE_VERSION checks only apply to the
  # full Xcode toolchain; CLT-only builds skip them and rely on the SDK
  # version check above.
  if(OBS_PLUS_NON_XCODE_BUILD)
    return()
  endif()

  execute_process(COMMAND xcrun --find xcodebuild OUTPUT_VARIABLE obs_macos_xcodebuild RESULT_VARIABLE result)
  if(NOT result EQUAL 0)
    message(
      FATAL_ERROR
      "Xcode was not found. "
      "Ensure you have installed Xcode and that xcode-select points at the Xcode developer directory."
    )
  endif()
  message(DEBUG "Path to xcodebuild binary: ${obs_macos_xcodebuild}")
  if(XCODE_VERSION VERSION_LESS obs_macos_minimum_xcode)
    message(
      FATAL_ERROR
      "Your Xcode version (${XCODE_VERSION}) is too low. Xcode ${obs_macos_minimum_xcode} is required to build OBS."
    )
  endif()
endfunction()

check_sdk_requirements()

# Enable dSYM generator for release builds
string(APPEND CMAKE_C_FLAGS_RELEASE " -g")
string(APPEND CMAKE_CXX_FLAGS_RELEASE " -g")
string(APPEND CMAKE_OBJC_FLAGS_RELEASE " -g")
string(APPEND CMAKE_OBJCXX_FLAGS_RELEASE " -g")

# Default ObjC compiler options used by Xcode:
#
# * -Wno-implicit-atomic-properties
# * -Wno-objc-interface-ivars
# * -Warc-repeated-use-of-weak
# * -Wno-arc-maybe-repeated-use-of-weak
# * -Wimplicit-retain-self
# * -Wduplicate-method-match
# * -Wshadow
# * -Wfloat-conversion
# * -Wobjc-literal-conversion
# * -Wno-selector
# * -Wno-strict-selector-match
# * -Wundeclared-selector
# * -Wdeprecated-implementations
# * -Wprotocol
# * -Werror=block-capture-autoreleasing
# * -Wrange-loop-analysis

# Default ObjC++ compiler options used by Xcode:
#
# * -Wno-non-virtual-dtor

add_compile_definitions(
  $<$<CONFIG:DEBUG>:DEBUG>
  $<$<NOT:$<COMPILE_LANGUAGE:Swift>>:$<$<CONFIG:DEBUG>:_DEBUG>>
  $<$<NOT:$<COMPILE_LANGUAGE:Swift>>:SIMDE_ENABLE_OPENMP>
)

if(ENABLE_COMPILER_TRACE)
  add_compile_options(
    $<$<NOT:$<COMPILE_LANGUAGE:Swift>>:-ftime-trace>
    "$<$<COMPILE_LANGUAGE:Swift>:SHELL:-Xfrontend -debug-time-expression-type-checking>"
    "$<$<COMPILE_LANGUAGE:Swift>:SHELL:-Xfrontend -debug-time-function-bodies>"
  )
  add_link_options(LINKER:-print_statistics)
endif()
