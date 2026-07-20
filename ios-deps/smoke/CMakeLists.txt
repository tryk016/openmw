cmake_minimum_required(VERSION 3.25)
project(OpenMWIOSDepsSmoke VERSION 0.1.0 LANGUAGES C OBJCXX)

if(NOT CMAKE_SYSTEM_NAME STREQUAL "iOS")
    message(FATAL_ERROR "The dependency smoke app must target iOS")
endif()
if(NOT CMAKE_GENERATOR STREQUAL "Xcode")
    message(FATAL_ERROR "The dependency smoke app requires the Xcode generator")
endif()
if(NOT IOS_DEPS_PREFIX)
    message(FATAL_ERROR "IOS_DEPS_PREFIX is required")
endif()

set(zlib_archive "${IOS_DEPS_PREFIX}/lib/libz.a")
if(NOT EXISTS "${zlib_archive}")
    message(FATAL_ERROR "The locked zlib archive is missing: ${zlib_archive}")
endif()

add_library(openmw-ios-zlib STATIC IMPORTED GLOBAL)
set_target_properties(openmw-ios-zlib PROPERTIES
    IMPORTED_LOCATION "${zlib_archive}"
    INTERFACE_INCLUDE_DIRECTORIES "${IOS_DEPS_PREFIX}/include")

find_library(UIKIT_FRAMEWORK UIKit REQUIRED)
find_library(FOUNDATION_FRAMEWORK Foundation REQUIRED)

add_executable(openmw-ios-deps-smoke MACOSX_BUNDLE Main.mm)
target_link_libraries(openmw-ios-deps-smoke PRIVATE
    openmw-ios-zlib
    "${UIKIT_FRAMEWORK}"
    "${FOUNDATION_FRAMEWORK}")
set_target_properties(openmw-ios-deps-smoke PROPERTIES
    OUTPUT_NAME "OpenMWDepsSmoke"
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Info.plist.in"
    XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "NO"
    XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED "NO"
    XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY ""
    XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "16.4"
    XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "org.openmw.ios.deps-smoke"
    XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2")
