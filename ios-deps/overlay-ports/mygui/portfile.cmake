if(NOT VCPKG_TARGET_IS_IOS OR NOT VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
    message(FATAL_ERROR "The OpenMW mygui overlay supports only arm64 iOS targets.")
endif()

vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

# Tag MyGUI3.4.3 resolves to dae9ac4be5a09e672bec509b1a8552b107c40214.
# SHA256: 33c91b531993047e77cace36d6fea73634b8c17bd0ed193d4cd12ac7c6328abd
vcpkg_download_distfile(ARCHIVE
    URLS "https://codeload.github.com/MyGUI/mygui/tar.gz/refs/tags/MyGUI3.4.3"
    FILENAME "mygui-MyGUI3.4.3.tar.gz"
    SHA512 88c69ca2e706af364b72d425f95013eb285501881d8094f8d67e31a54c45ca11b0eb5b62c382af0d4c43f69aa8197648259ac306b72efa7ef3e25eecb9b039cb
)

vcpkg_extract_source_archive(SOURCE_PATH
    ARCHIVE "${ARCHIVE}"
    PATCHES
        llvm-char-types.patch
        ios-engine-only.patch
        numeric-version-print.patch
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DMYGUI_STATIC=ON
        -DMYGUI_DISABLE_PLUGINS=ON
        -DMYGUI_USE_FREETYPE=ON
        -DMYGUI_MSDF_FONTS=OFF
        -DMYGUI_DONT_USE_OBSOLETE=ON
        -DMYGUI_BUILD_PLATFORM=OFF
        -DMYGUI_RENDERSYSTEM=1
        -DMYGUI_BUILD_DEMOS=OFF
        -DMYGUI_BUILD_PLUGINS=OFF
        -DMYGUI_BUILD_TOOLS=OFF
        -DMYGUI_BUILD_UNITTESTS=OFF
        -DMYGUI_BUILD_TEST_APP=OFF
        -DMYGUI_BUILD_WRAPPER=OFF
        -DMYGUI_BUILD_DOCS=OFF
        -DMYGUI_INSTALL_DEMOS=OFF
        -DMYGUI_INSTALL_TOOLS=OFF
        -DMYGUI_INSTALL_DOCS=OFF
        -DMYGUI_INSTALL_PDB=OFF
        -DMYGUI_CLANG_TIDY_BUILD=OFF
        -DCMAKE_DISABLE_PRECOMPILE_HEADERS=ON
)

vcpkg_cmake_install()
vcpkg_fixup_pkgconfig()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/bin"
    "${CURRENT_PACKAGES_DIR}/debug/bin"
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/lib"
    "${CURRENT_PACKAGES_DIR}/debug/share"
    "${CURRENT_PACKAGES_DIR}/lib/MYGUI"
)

foreach(required_file IN ITEMS
    "${CURRENT_PACKAGES_DIR}/include/MYGUI/MyGUI.h"
    "${CURRENT_PACKAGES_DIR}/include/MYGUI/MyGUI_Prerequest.h"
    "${CURRENT_PACKAGES_DIR}/lib/libMyGUIEngineStatic.a"
)
    if(NOT EXISTS "${required_file}")
        message(FATAL_ERROR "MyGUI engine-only install is missing ${required_file}")
    endif()
endforeach()

file(GLOB_RECURSE INSTALLED_STATIC_LIBRARIES LIST_DIRECTORIES false
    "${CURRENT_PACKAGES_DIR}/lib/*.a"
    "${CURRENT_PACKAGES_DIR}/debug/lib/*.a"
)
list(SORT INSTALLED_STATIC_LIBRARIES)
set(EXPECTED_STATIC_LIBRARIES
    "${CURRENT_PACKAGES_DIR}/lib/libMyGUIEngineStatic.a"
)
list(SORT EXPECTED_STATIC_LIBRARIES)
if(NOT INSTALLED_STATIC_LIBRARIES STREQUAL EXPECTED_STATIC_LIBRARIES)
    message(FATAL_ERROR "Unexpected MyGUI static library set: ${INSTALLED_STATIC_LIBRARIES}")
endif()

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/COPYING.MIT")
