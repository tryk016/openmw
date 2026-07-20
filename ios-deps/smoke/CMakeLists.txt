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

set(ZLIB_USE_STATIC_LIBS ON)
set(ZLIB_INCLUDE_DIR "${IOS_DEPS_PREFIX}/include")
set(ZLIB_LIBRARY "${zlib_archive}")
set(ZLIB_LIBRARY_RELEASE "${zlib_archive}")
find_package(ZLIB 1.3.1 REQUIRED)

find_package(SDL2 2.32.10 CONFIG REQUIRED
    PATHS "${IOS_DEPS_PREFIX}/share/sdl2"
    NO_DEFAULT_PATH
    NO_CMAKE_FIND_ROOT_PATH)
if(TARGET SDL2::SDL2)
    set(sdl2_target SDL2::SDL2)
elseif(TARGET SDL2::SDL2-static)
    set(sdl2_target SDL2::SDL2-static)
else()
    message(FATAL_ERROR "The locked SDL2 package has no static CMake target")
endif()

find_package(lz4 1.10.0 CONFIG REQUIRED
    PATHS "${IOS_DEPS_PREFIX}/share/lz4"
    NO_DEFAULT_PATH
    NO_CMAKE_FIND_ROOT_PATH)
if(NOT TARGET lz4::lz4)
    message(FATAL_ERROR "The locked LZ4 package has no lz4::lz4 target")
endif()

set(freetype_archive "${IOS_DEPS_PREFIX}/lib/libfreetype.a")
set(png_archive "${IOS_DEPS_PREFIX}/lib/libpng16.a")
set(jpeg_archive "${IOS_DEPS_PREFIX}/lib/libjpeg.a")
foreach(archive IN ITEMS
        "${freetype_archive}"
        "${png_archive}"
        "${jpeg_archive}")
    if(NOT EXISTS "${archive}")
        message(FATAL_ERROR "A locked image archive is missing: ${archive}")
    endif()
endforeach()

# The pinned vcpkg port intentionally flattens include/freetype2 into include.
set(FREETYPE_INCLUDE_DIR_ft2build "${IOS_DEPS_PREFIX}/include")
set(FREETYPE_INCLUDE_DIR_freetype2 "${IOS_DEPS_PREFIX}/include")
set(FREETYPE_LIBRARY "${freetype_archive}")
set(FREETYPE_LIBRARY_RELEASE "${freetype_archive}")
find_package(Freetype 2.13.3 REQUIRED)

set(PNG_PNG_INCLUDE_DIR "${IOS_DEPS_PREFIX}/include")
set(PNG_LIBRARY "${png_archive}")
set(PNG_LIBRARY_RELEASE "${png_archive}")
find_package(PNG 1.6.54 REQUIRED)

set(JPEG_INCLUDE_DIR "${IOS_DEPS_PREFIX}/include")
set(JPEG_LIBRARY "${jpeg_archive}")
set(JPEG_LIBRARY_RELEASE "${jpeg_archive}")
find_package(JPEG REQUIRED)

find_package(libjpeg-turbo 3.1.3 CONFIG REQUIRED
    PATHS "${IOS_DEPS_PREFIX}/share/libjpeg-turbo"
    NO_DEFAULT_PATH
    NO_CMAKE_FIND_ROOT_PATH)
if(TARGET libjpeg-turbo::turbojpeg)
    set(turbojpeg_target libjpeg-turbo::turbojpeg)
elseif(TARGET libjpeg-turbo::turbojpeg-static)
    set(turbojpeg_target libjpeg-turbo::turbojpeg-static)
else()
    message(FATAL_ERROR
        "The locked libjpeg-turbo package has no TurboJPEG C API target")
endif()

find_library(UIKIT_FRAMEWORK UIKit REQUIRED)
find_library(FOUNDATION_FRAMEWORK Foundation REQUIRED)

add_executable(openmw-ios-deps-smoke MACOSX_BUNDLE Main.mm)
target_compile_definitions(openmw-ios-deps-smoke PRIVATE SDL_MAIN_HANDLED)
target_link_options(openmw-ios-deps-smoke PRIVATE "LINKER:-ObjC")
target_link_libraries(openmw-ios-deps-smoke PRIVATE
    ZLIB::ZLIB
    "${sdl2_target}"
    lz4::lz4
    Freetype::Freetype
    PNG::PNG
    JPEG::JPEG
    "${turbojpeg_target}"
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

add_executable(openmw-ios-jpeg-probe JpegProbe.c)
target_link_libraries(openmw-ios-jpeg-probe PRIVATE JPEG::JPEG)
set_target_properties(openmw-ios-jpeg-probe PROPERTIES
    OUTPUT_NAME "OpenMWJPEGProbe"
    XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "NO"
    XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED "NO"
    XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY ""
    XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "16.4")

add_executable(openmw-ios-turbojpeg-probe TurboJpegProbe.c)
target_link_libraries(openmw-ios-turbojpeg-probe PRIVATE "${turbojpeg_target}")
set_target_properties(openmw-ios-turbojpeg-probe PROPERTIES
    OUTPUT_NAME "OpenMWTurboJPEGProbe"
    XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "NO"
    XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED "NO"
    XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY ""
    XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "16.4")
