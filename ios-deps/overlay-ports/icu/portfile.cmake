if(VCPKG_TARGET_IS_OSX)
    if(NOT VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64" OR
            NOT "tools" IN_LIST FEATURES)
        message(FATAL_ERROR
            "The OpenMW ICU host overlay requires arm64 macOS and the tools feature.")
    endif()
elseif(VCPKG_TARGET_IS_IOS)
    if(NOT VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64" OR
            "tools" IN_LIST FEATURES)
        message(FATAL_ERROR
            "The OpenMW ICU target overlay supports arm64 iOS without target tools.")
    endif()
else()
    message(FATAL_ERROR
        "The OpenMW ICU overlay supports only the arm64 macOS host and arm64 iOS targets.")
endif()

vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_download_distfile(
    ARCHIVE
    URLS "https://codeload.github.com/unicode-org/icu/tar.gz/refs/tags/release-70-1"
    FILENAME "icu-release-70-1.tar.gz"
    SHA512 f1a653452f42605f799de7ec1d5bf27aa4b715f2ec18534cd3b52bd9be7ddbe7a6d18b47e3a5b36c7a63442bc38304ddc80f519ac65b9a91978ab15b462d9456
)

vcpkg_extract_source_archive(
    SOURCE_PATH
    ARCHIVE "${ARCHIVE}"
    PATCHES
        disable-static-prefix.patch
        disable-escapesrc-tool.patch
)

vcpkg_find_acquire_program(PYTHON3)
set(ENV{PYTHON} "${PYTHON3}")

set(configure_options
    --enable-static
    --disable-shared
    --disable-tests
    --disable-samples
    --disable-layoutex
    --disable-icuio
    --disable-extras
    --with-data-packaging=static
)
set(build_options)

if(VCPKG_TARGET_IS_OSX)
    list(APPEND configure_options --enable-tools)
else()
    list(APPEND configure_options --disable-tools)

    set(host_tool_root "${CURRENT_HOST_INSTALLED_DIR}/tools/${PORT}")
    if(NOT EXISTS "${host_tool_root}/config/icucross.mk")
        message(FATAL_ERROR
            "The pinned ICU host cross-build metadata is missing: ${host_tool_root}/config/icucross.mk")
    endif()
    list(APPEND configure_options "--with-cross-build=${host_tool_root}")

    set(filter_source "${CMAKE_CURRENT_LIST_DIR}/../../../extern/icufilters.json")
    if(NOT EXISTS "${filter_source}")
        message(FATAL_ERROR "The OpenMW ICU data filter is missing: ${filter_source}")
    endif()
    file(READ "${filter_source}" filter_contents)
    string(REPLACE "\r\n" "\n" filter_contents "${filter_contents}")
    set(filter_file "${CURRENT_BUILDTREES_DIR}/openmw-icufilters.json")
    file(WRITE "${filter_file}" "${filter_contents}")
    file(SHA256 "${filter_file}" filter_sha256)
    file(SHA512 "${filter_file}" filter_sha512)
    if(NOT filter_sha256 STREQUAL
            "05533f4c0bf0b50c93ab3e0fb8a09a98965f1ea58510144b0c9e0239671f3a6f" OR
            NOT filter_sha512 STREQUAL
            "e4d91a6daa494331729e9791e17db60dc467fbbcd6c121069ccd339781bfff1419ea170f21ad7b190a8755d52afbcc8722096695128fe36b04e24279d28c25ea")
        message(FATAL_ERROR "The canonical OpenMW ICU data filter hash changed.")
    endif()
    set(ICU_DATA_FILTER_FILE "${filter_file}")
    list(APPEND build_options
        "PKGDATA_OPTS=--without-assembly -O ../data/icupkg.inc")
endif()

vcpkg_configure_make(
    SOURCE_PATH "${SOURCE_PATH}"
    PROJECT_SUBPATH icu4c/source
    DETERMINE_BUILD_TRIPLET
    CONFIGURE_ENVIRONMENT_VARIABLES ICU_DATA_FILTER_FILE
    OPTIONS
        ${configure_options}
    OPTIONS_RELEASE
        --disable-debug
        --enable-release
)
vcpkg_install_make(OPTIONS ${build_options})

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/share"
    "${CURRENT_PACKAGES_DIR}/debug/share"
    "${CURRENT_PACKAGES_DIR}/lib/icu"
    "${CURRENT_PACKAGES_DIR}/debug/lib/icu"
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/lib"
    "${CURRENT_PACKAGES_DIR}/debug/bin"
    "${CURRENT_PACKAGES_DIR}/debug/tools"
)

if(VCPKG_TARGET_IS_OSX)
    vcpkg_copy_tools(
        TOOL_NAMES icupkg gennorm2 gencmn genccode gensprep
        SEARCH_DIR "${CURRENT_PACKAGES_DIR}/tools/icu/sbin"
        DESTINATION "${CURRENT_PACKAGES_DIR}/tools/${PORT}/bin"
    )
    file(REMOVE_RECURSE
        "${CURRENT_PACKAGES_DIR}/tools/icu/sbin"
        "${CURRENT_PACKAGES_DIR}/tools/icu/debug"
    )
    file(GLOB cross_compile_defs
        "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/config/icucross.*")
    if(NOT cross_compile_defs)
        message(FATAL_ERROR "ICU host cross-build metadata was not generated.")
    endif()
    file(INSTALL ${cross_compile_defs}
        DESTINATION "${CURRENT_PACKAGES_DIR}/tools/${PORT}/config")
else()
    file(REMOVE_RECURSE
        "${CURRENT_PACKAGES_DIR}/bin"
        "${CURRENT_PACKAGES_DIR}/sbin"
        "${CURRENT_PACKAGES_DIR}/tools"
    )
    file(GLOB installed_icu_archives
        "${CURRENT_PACKAGES_DIR}/lib/libicu*.a")
    list(SORT installed_icu_archives)
    set(expected_icu_archives
        "${CURRENT_PACKAGES_DIR}/lib/libicudata.a"
        "${CURRENT_PACKAGES_DIR}/lib/libicui18n.a"
        "${CURRENT_PACKAGES_DIR}/lib/libicuuc.a"
    )
    list(SORT expected_icu_archives)
    if(NOT installed_icu_archives STREQUAL expected_icu_archives)
        message(FATAL_ERROR
            "Unexpected ICU iOS archive set: ${installed_icu_archives}")
    endif()
endif()

if(VCPKG_LIBRARY_LINKAGE STREQUAL "static")
    foreach(header utypes.h utf_old.h platform.h)
        vcpkg_replace_string(
            "${CURRENT_PACKAGES_DIR}/include/unicode/${header}"
            "defined(U_STATIC_IMPLEMENTATION)"
            "1"
        )
    endforeach()
endif()

vcpkg_fixup_pkgconfig(SYSTEM_LIBRARIES pthread m)
configure_file(
    "${CMAKE_CURRENT_LIST_DIR}/vcpkg-cmake-wrapper.cmake"
    "${CURRENT_PACKAGES_DIR}/share/${PORT}/vcpkg-cmake-wrapper.cmake"
    COPYONLY
)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/icu4c/LICENSE")
