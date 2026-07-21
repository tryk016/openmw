if(NOT VCPKG_TARGET_IS_IOS OR NOT VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
    message(FATAL_ERROR "The OpenMW openal-soft overlay supports only arm64 iOS targets.")
endif()

vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_download_distfile(ARCHIVE
    URLS "https://codeload.github.com/kcat/openal-soft/tar.gz/refs/tags/1.24.3"
    FILENAME "openal-soft-1.24.3.tar.gz"
    # SHA256: 7e1fecdeb45e7f78722b776c5cf30bd33934b961d7fd2a11e0494e064cc631ce
    SHA512 3eebd18de4984691136738e8fe5851ac5dbdc8f17916cc9dcc599bd3bafc400c9dad9dc88844a9b77b1e8e372a041af342421bdf23746dffe4760f8385bd1e53
)

vcpkg_extract_source_archive(
    SOURCE_PATH
    ARCHIVE "${ARCHIVE}"
)

# OpenAL Soft compiles MIT-licensed implementation sources whose notices are
# embedded in source headers rather than separate license files. Extract the
# complete leading MIT grants from the pinned sources instead of maintaining
# hand-copied text that could drift from the archive.
function(openmw_extract_mit_notice SOURCE_FILE OUTPUT_FILE STYLE ATTRIBUTION)
    file(STRINGS "${SOURCE_FILE}" source_lines ENCODING UTF-8)
    set(capturing FALSE)
    set(complete FALSE)
    set(notice "")
    foreach(source_line IN LISTS source_lines)
        if(NOT capturing)
            if(STYLE STREQUAL "BLOCK" AND source_line MATCHES "^/\\*-")
                set(capturing TRUE)
            elseif(STYLE STREQUAL "LINE" AND
                    source_line MATCHES "^// Copyright \\(c\\)")
                set(capturing TRUE)
            endif()
        endif()
        if(capturing)
            string(APPEND notice "${source_line}\n")
            if(STYLE STREQUAL "BLOCK" AND
                    source_line MATCHES "^[ \\t]*\\*/$")
                set(complete TRUE)
                break()
            elseif(STYLE STREQUAL "LINE" AND
                    source_line STREQUAL "// SOFTWARE.")
                set(complete TRUE)
                break()
            endif()
        endif()
    endforeach()
    if(NOT complete OR NOT notice MATCHES "${ATTRIBUTION}" OR
            NOT notice MATCHES "Permission is hereby granted" OR
            NOT notice MATCHES "included in all" OR
            NOT notice MATCHES "copies or substantial portions" OR
            NOT notice MATCHES "THE SOFTWARE IS PROVIDED .AS IS." OR
            NOT notice MATCHES "LIABILITY")
        message(FATAL_ERROR
            "Unable to extract the complete MIT notice from ${SOURCE_FILE}")
    endif()
    file(WRITE "${OUTPUT_FILE}" "${notice}")
endfunction()

set(OPENMW_OPENAL_NOTICE_DIR
    "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-notices")
file(REMOVE_RECURSE "${OPENMW_OPENAL_NOTICE_DIR}")
file(MAKE_DIRECTORY "${OPENMW_OPENAL_NOTICE_DIR}")
set(OPENMW_OPENAL_BS2B_NOTICE
    "${OPENMW_OPENAL_NOTICE_DIR}/bs2b-MIT.txt")
set(OPENMW_OPENAL_FILESYSTEM_NOTICE
    "${OPENMW_OPENAL_NOTICE_DIR}/filesystem-MIT.txt")
set(OPENMW_OPENAL_GHC_FILESYSTEM_NOTICE
    "${OPENMW_OPENAL_NOTICE_DIR}/ghc-filesystem-MIT.txt")
openmw_extract_mit_notice(
    "${SOURCE_PATH}/core/bs2b.cpp"
    "${OPENMW_OPENAL_BS2B_NOTICE}"
    BLOCK "Copyright \\(c\\) 2005 Boris Mikhaylov")
openmw_extract_mit_notice(
    "${SOURCE_PATH}/common/filesystem.cpp"
    "${OPENMW_OPENAL_FILESYSTEM_NOTICE}"
    LINE "Copyright \\(c\\) 2018, Steffen")
openmw_extract_mit_notice(
    "${SOURCE_PATH}/common/ghc_filesystem.h"
    "${OPENMW_OPENAL_GHC_FILESYSTEM_NOTICE}"
    LINE "Copyright \\(c\\) 2018, Steffen")

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DLIBTYPE=STATIC
        -DALSOFT_DLOPEN=OFF
        -DALSOFT_UTILS=OFF
        -DALSOFT_NO_CONFIG_UTIL=ON
        -DALSOFT_EXAMPLES=OFF
        -DALSOFT_TESTS=OFF
        -DALSOFT_INSTALL=ON
        -DALSOFT_INSTALL_CONFIG=OFF
        -DALSOFT_INSTALL_HRTF_DATA=OFF
        -DALSOFT_INSTALL_AMBDEC_PRESETS=OFF
        -DALSOFT_INSTALL_EXAMPLES=OFF
        -DALSOFT_INSTALL_UTILS=OFF
        -DALSOFT_UPDATE_BUILD_VERSION=OFF
        -DALSOFT_EAX=OFF
        -DALSOFT_SEARCH_INSTALL_DATADIR=OFF
        -DALSOFT_OSX_FRAMEWORK=OFF
        -DALSOFT_RTKIT=OFF
        -DALSOFT_CPUEXT_SSE=OFF
        -DALSOFT_CPUEXT_SSE2=OFF
        -DALSOFT_CPUEXT_SSE3=OFF
        -DALSOFT_CPUEXT_SSE4_1=OFF
        -DALSOFT_CPUEXT_NEON=ON
        -DALSOFT_REQUIRE_NEON=ON
        -DALSOFT_EMBED_HRTF_DATA=ON
        -DALSOFT_BACKEND_PIPEWIRE=OFF
        -DALSOFT_BACKEND_PULSEAUDIO=OFF
        -DALSOFT_BACKEND_ALSA=OFF
        -DALSOFT_BACKEND_OSS=OFF
        -DALSOFT_BACKEND_SOLARIS=OFF
        -DALSOFT_BACKEND_SNDIO=OFF
        -DALSOFT_BACKEND_WINMM=OFF
        -DALSOFT_BACKEND_DSOUND=OFF
        -DALSOFT_BACKEND_WASAPI=OFF
        -DALSOFT_BACKEND_OTHERIO=OFF
        -DALSOFT_BACKEND_JACK=OFF
        -DALSOFT_BACKEND_COREAUDIO=ON
        -DALSOFT_REQUIRE_COREAUDIO=ON
        -DALSOFT_BACKEND_OBOE=OFF
        -DALSOFT_BACKEND_OPENSL=OFF
        -DALSOFT_BACKEND_PORTAUDIO=OFF
        -DALSOFT_BACKEND_SDL3=OFF
        -DALSOFT_BACKEND_SDL2=OFF
        -DALSOFT_BACKEND_WAVE=OFF
    MAYBE_UNUSED_VARIABLES
        ALSOFT_BACKEND_ALSA
        ALSOFT_BACKEND_OSS
        ALSOFT_BACKEND_SOLARIS
        ALSOFT_BACKEND_SNDIO
        ALSOFT_BACKEND_WINMM
        ALSOFT_BACKEND_DSOUND
        ALSOFT_BACKEND_WASAPI
        ALSOFT_BACKEND_OTHERIO
        ALSOFT_OSX_FRAMEWORK
)

vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH "lib/cmake/OpenAL")

# Make the installed headers unambiguously describe a static OpenAL library,
# including for consumers that use FindOpenAL instead of the exported target.
foreach(HEADER IN ITEMS al.h alc.h)
    vcpkg_replace_string(
        "${CURRENT_PACKAGES_DIR}/include/AL/${HEADER}"
        "defined(AL_LIBTYPE_STATIC)"
        "1"
    )
endforeach()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
    "${CURRENT_PACKAGES_DIR}/lib/pkgconfig"
    "${CURRENT_PACKAGES_DIR}/debug/lib/pkgconfig"
    "${CURRENT_PACKAGES_DIR}/bin"
    "${CURRENT_PACKAGES_DIR}/debug/bin"
)

file(INSTALL
    "${OPENMW_OPENAL_BS2B_NOTICE}"
    "${OPENMW_OPENAL_FILESYSTEM_NOTICE}"
    "${OPENMW_OPENAL_GHC_FILESYSTEM_NOTICE}"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}/notices"
)

vcpkg_install_copyright(
    FILE_LIST
        "${SOURCE_PATH}/COPYING"
        "${SOURCE_PATH}/BSD-3Clause"
        "${SOURCE_PATH}/LICENSE-pffft"
        "${SOURCE_PATH}/fmt-11.1.1/LICENSE"
        "${OPENMW_OPENAL_BS2B_NOTICE}"
        "${OPENMW_OPENAL_FILESYSTEM_NOTICE}"
        "${OPENMW_OPENAL_GHC_FILESYSTEM_NOTICE}"
)
