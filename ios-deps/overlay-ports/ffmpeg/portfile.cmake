if(NOT VCPKG_TARGET_IS_IOS OR NOT VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
    message(FATAL_ERROR "The OpenMW ffmpeg overlay supports only arm64 iOS targets.")
endif()
if(NOT VCPKG_BUILD_TYPE STREQUAL "release")
    message(FATAL_ERROR "The OpenMW ffmpeg overlay requires the release-only project triplets.")
endif()
if(NOT VCPKG_OSX_DEPLOYMENT_TARGET OR VCPKG_OSX_DEPLOYMENT_TARGET VERSION_LESS "16.4")
    message(FATAL_ERROR "The OpenMW ffmpeg overlay requires iOS 16.4 or newer.")
endif()
if(NOT VCPKG_OSX_SYSROOT MATCHES "^(iphoneos|iphonesimulator)$")
    message(FATAL_ERROR "VCPKG_OSX_SYSROOT must be iphoneos or iphonesimulator.")
endif()

vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_download_distfile(ARCHIVE
    URLS "https://ffmpeg.org/releases/ffmpeg-7.1.1.tar.xz"
    FILENAME "ffmpeg-7.1.1.tar.xz"
    # SHA256: 733984395e0dbbe5c046abda2dc49a5544e7e0e1e2366bba849222ae9e3a03b1
    SHA512 42486e485c8fc6f3ec61598a1a7cb40360535762b3fcf28c10d7c6840bc55afe3334434912746e69eef862d3cedf45a02953bde73d38547d2d9a7a38a65e123a
)

vcpkg_extract_source_archive(
    SOURCE_PATH
    ARCHIVE "${ARCHIVE}"
    PATCHES
        0020-fix-aarch64-libswscale.patch
)

vcpkg_cmake_get_vars(cmake_vars_file)
include("${cmake_vars_file}")

foreach(required_tool IN ITEMS
        VCPKG_DETECTED_CMAKE_C_COMPILER
        VCPKG_DETECTED_CMAKE_CXX_COMPILER
        VCPKG_DETECTED_CMAKE_AR
        VCPKG_DETECTED_CMAKE_NM
        VCPKG_DETECTED_CMAKE_RANLIB
        VCPKG_DETECTED_CMAKE_STRIP)
    if(NOT DEFINED ${required_tool}
            OR "${${required_tool}}" STREQUAL ""
            OR "${${required_tool}}" MATCHES "-NOTFOUND$")
        message(FATAL_ERROR "The iOS toolchain did not provide ${required_tool}.")
    endif()
endforeach()

find_program(HOST_CC NAMES clang cc REQUIRED)
find_program(BASH NAMES bash REQUIRED)
find_program(MAKE NAMES make REQUIRED)

execute_process(
    COMMAND /usr/bin/xcrun --sdk "${VCPKG_OSX_SYSROOT}" --show-sdk-path
    RESULT_VARIABLE xcrun_result
    OUTPUT_VARIABLE IOS_SDK_PATH
    ERROR_VARIABLE xcrun_error
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_STRIP_TRAILING_WHITESPACE
)
if(NOT xcrun_result EQUAL 0 OR NOT IS_DIRECTORY "${IOS_SDK_PATH}")
    message(FATAL_ERROR
        "Unable to resolve the ${VCPKG_OSX_SYSROOT} SDK with xcrun: ${xcrun_error}")
endif()

if(VCPKG_OSX_SYSROOT STREQUAL "iphoneos")
    set(IOS_TARGET_TRIPLE "arm64-apple-ios${VCPKG_OSX_DEPLOYMENT_TARGET}")
else()
    set(IOS_TARGET_TRIPLE "arm64-apple-ios${VCPKG_OSX_DEPLOYMENT_TARGET}-simulator")
endif()

# OpenMW reads all media through a custom AVIOContext, so no URL protocol is
# needed. The allowlist comes from the repository's actual assets/contracts:
# Bink movies; MP3 music/voice; 16-bit/u8 WAV effects; documented Ogg music;
# and the project's WebM videos (VP8/VP9 with Vorbis/Opus audio).
set(CONFIGURE_OPTIONS
    --target-os=darwin
    --arch=arm64
    --enable-cross-compile
    --pkg-config=/usr/bin/false
    "--extra-cflags=--target=${IOS_TARGET_TRIPLE}"
    "--extra-ldflags=--target=${IOS_TARGET_TRIPLE}"
    --enable-pic
    --enable-static
    --disable-shared
    --enable-small
    --enable-optimizations
    --disable-debug
    --disable-stripping
    --enable-pthreads
    --disable-runtime-cpudetect
    --enable-asm
    --enable-inline-asm
    --enable-neon
    --disable-x86asm
    --disable-autodetect
    --disable-network
    --disable-protocols
    --disable-devices
    --disable-indevs
    --disable-outdevs
    --disable-programs
    --disable-doc
    --disable-everything
    --disable-encoders
    --disable-muxers
    --disable-filters
    --disable-hwaccels
    --disable-gpl
    --disable-nonfree
    --disable-version3
    --disable-avdevice
    --disable-avfilter
    --disable-postproc
    --disable-audiotoolbox
    --disable-avfoundation
    --disable-coreimage
    --disable-videotoolbox
    --disable-securetransport
    --disable-iconv
    --disable-zlib
    --disable-bzlib
    --disable-lzma
    --enable-avcodec
    --enable-avformat
    --enable-avutil
    --enable-swscale
    --enable-swresample
    --enable-demuxer=bink,matroska,mp3,ogg,wav
    --enable-decoder=bink,binkaudio_dct,binkaudio_rdft,mp3,pcm_s16le,pcm_u8,vorbis,opus,vp8,vp9
    --enable-parser=mpegaudio,vp9
    --enable-bsf=vp9_superframe_split
)
list(JOIN CONFIGURE_OPTIONS "\n" CONFIGURE_OPTIONS_EVIDENCE)
list(JOIN CONFIGURE_OPTIONS " " CONFIGURE_OPTIONS)

set(BUILD_PATH "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel")
set(PACKAGE_PATH "${CURRENT_PACKAGES_DIR}")
file(REMOVE_RECURSE "${BUILD_PATH}")
file(MAKE_DIRECTORY "${BUILD_PATH}")
file(WRITE "${BUILD_PATH}/openmw-configure-options.txt"
    "${CONFIGURE_OPTIONS_EVIDENCE}\n")
file(WRITE "${BUILD_PATH}/openmw-corresponding-source.txt"
    "source=https://ffmpeg.org/releases/ffmpeg-7.1.1.tar.xz\n"
    "sha256=733984395e0dbbe5c046abda2dc49a5544e7e0e1e2366bba849222ae9e3a03b1\n"
    "patch=0020-fix-aarch64-libswscale.patch\n")

set(CFLAGS_RSP "${BUILD_PATH}/cflags.rsp")
string(REGEX REPLACE "(^| )-arch +[^ ]+" "\\1" release_c_flags
    "${VCPKG_COMBINED_C_FLAGS_RELEASE}")
file(WRITE "${CFLAGS_RSP}" "${release_c_flags}")

set(LDFLAGS_RSP "${BUILD_PATH}/ldflags.rsp")
string(REGEX REPLACE "(^| )-arch +[^ ]+" "\\1" release_ld_flags
    "${VCPKG_COMBINED_SHARED_LINKER_FLAGS_RELEASE}")
file(WRITE "${LDFLAGS_RSP}" "${release_ld_flags}")

configure_file("${CMAKE_CURRENT_LIST_DIR}/build.sh.in" "${BUILD_PATH}/build.sh" @ONLY)

vcpkg_execute_required_process(
    COMMAND "${BASH}" ./build.sh
    WORKING_DIRECTORY "${BUILD_PATH}"
    LOGNAME "build-${TARGET_TRIPLET}-rel"
    SAVE_LOG_FILES ffbuild/config.log
)

vcpkg_fixup_pkgconfig()

file(INSTALL
    "${BUILD_PATH}/config.h"
    "${BUILD_PATH}/config_components.h"
    "${BUILD_PATH}/openmw-configure-options.txt"
    "${BUILD_PATH}/openmw-corresponding-source.txt"
    "${CMAKE_CURRENT_LIST_DIR}/0020-fix-aarch64-libswscale.patch"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
)

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug"
    "${CURRENT_PACKAGES_DIR}/bin"
)

file(INSTALL
    "${CMAKE_CURRENT_LIST_DIR}/vcpkg-cmake-wrapper.cmake"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
)

vcpkg_install_copyright(
    FILE_LIST
        "${SOURCE_PATH}/COPYING.LGPLv2.1"
        "${SOURCE_PATH}/COPYING.LGPLv3"
        "${SOURCE_PATH}/LICENSE.md"
)
