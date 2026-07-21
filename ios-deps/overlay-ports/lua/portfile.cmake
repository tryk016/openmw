if(NOT VCPKG_TARGET_IS_IOS OR NOT VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
    message(FATAL_ERROR "The OpenMW Lua overlay supports only arm64 iOS targets.")
endif()

vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_download_distfile(
    ARCHIVE
    URLS "https://www.lua.org/ftp/lua-5.1.5.tar.gz"
    FILENAME "lua-5.1.5.tar.gz"
    SHA512 0142fefcbd13afcd9b201403592aa60620011cc8e8559d4d2db2f92739d18186860989f48caa45830ff4f99bfc7483287fd3ff3a16d4dec928e2767ce4d542a9
)

vcpkg_extract_source_archive(
    SOURCE_PATH
    ARCHIVE "${ARCHIVE}"
    PATCHES
        ios-disable-process.patch
)

file(COPY "${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt"
    DESTINATION "${SOURCE_PATH}")

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DBUILD_SHARED_LIBS=OFF
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(
    PACKAGE_NAME unofficial-lua
    CONFIG_PATH share/unofficial-lua
)

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
    "${CURRENT_PACKAGES_DIR}/bin"
    "${CURRENT_PACKAGES_DIR}/debug/bin"
    "${CURRENT_PACKAGES_DIR}/tools"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/README")
