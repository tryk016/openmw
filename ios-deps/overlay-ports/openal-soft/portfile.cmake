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

vcpkg_install_copyright(
    FILE_LIST
        "${SOURCE_PATH}/COPYING"
        "${SOURCE_PATH}/BSD-3Clause"
        "${SOURCE_PATH}/LICENSE-pffft"
        "${SOURCE_PATH}/fmt-11.1.1/LICENSE"
)
