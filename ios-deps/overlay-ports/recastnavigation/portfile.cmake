if(NOT VCPKG_TARGET_IS_IOS OR NOT VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
    message(FATAL_ERROR "The OpenMW recastnavigation overlay supports only arm64 iOS targets.")
endif()

vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO OpenMW/recastnavigation
    REF 03259f3287ff8330f0d66fcd98d022edddffaa97
    SHA512 25062a97296ba8e0359c0653794cf657879d9048c431f25f672ddcfe52794f5a2ad391113a1e67342d659354694839ad97e769f85a2548d804d530148033c53a
    HEAD_REF main
    PATCHES
        ios-navigation-only.patch
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DBUILD_SHARED_LIBS=OFF
        -DRECASTNAVIGATION_DETOURCROWD=OFF
        -DRECASTNAVIGATION_DEMO=OFF
        -DRECASTNAVIGATION_TESTS=OFF
        -DRECASTNAVIGATION_EXAMPLES=OFF
        -DRECASTNAVIGATION_DT_POLYREF64=OFF
        -DRECASTNAVIGATION_DT_VIRTUAL_QUERYFILTER=OFF
)

vcpkg_cmake_install()
vcpkg_cmake_config_fixup(
    PACKAGE_NAME recastnavigation
    CONFIG_PATH lib/cmake/recastnavigation
)

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
    "${CURRENT_PACKAGES_DIR}/lib/pkgconfig"
    "${CURRENT_PACKAGES_DIR}/debug/lib/pkgconfig"
    "${CURRENT_PACKAGES_DIR}/bin"
    "${CURRENT_PACKAGES_DIR}/debug/bin"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/License.txt")
