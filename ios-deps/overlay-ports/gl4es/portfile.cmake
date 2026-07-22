if(NOT VCPKG_TARGET_IS_IOS OR NOT VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
    message(FATAL_ERROR "The OpenMW gl4es overlay supports only arm64 iOS targets.")
endif()
if(NOT VCPKG_BUILD_TYPE STREQUAL "release")
    message(FATAL_ERROR "The OpenMW gl4es overlay requires the release-only project triplets.")
endif()
if(NOT VCPKG_OSX_DEPLOYMENT_TARGET OR VCPKG_OSX_DEPLOYMENT_TARGET VERSION_LESS "16.4")
    message(FATAL_ERROR "The OpenMW gl4es overlay requires iOS 16.4 or newer.")
endif()
if(NOT VCPKG_OSX_SYSROOT MATCHES "^(iphoneos|iphonesimulator)$")
    message(FATAL_ERROR "VCPKG_OSX_SYSROOT must be iphoneos or iphonesimulator.")
endif()

vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_download_distfile(ARCHIVE
    URLS "https://codeload.github.com/ptitSeb/gl4es/tar.gz/refs/tags/v1.1.6"
    FILENAME "gl4es-1.1.6.tar.gz"
    # Tag v1.1.6 resolves to c9895df34cd466c23bc60c2bd3db3d87e98fcbe7.
    # SHA256: dca1d897e492a0cb163a3390f273fbd4cc7ab2367d236d93dc2b321ce108ed5c
    SHA512 6d76d958507d3d64639030b40799630ec0b6b4940cf45c6779d102cf45b41e691b50dedfb06606b3429ebe14de8fbdd6e46706be4483e9334236c41a5e0facfc
)

vcpkg_extract_source_archive(
    SOURCE_PATH
    ARCHIVE "${ARCHIVE}"
    PATCHES
        disable-tests.patch
        darwin-no-alias.patch
)

set(GL4ES_ARCHIVE_DIR "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel-output")

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DBUILD_SHARED_LIBS=OFF
        -DBUILD_TESTING=OFF
        -DNOX11=ON
        -DNOEGL=ON
        -DSTATICLIB=ON
        -DNO_LOADER=ON
        -DNO_INIT_CONSTRUCTOR=ON
        -DDEFAULT_ES=2
        -DPANDORA=OFF
        -DPYRA=OFF
        -DBCMHOST=OFF
        -DODROID=OFF
        -DGOA_CLONE=OFF
        -DANDROID=OFF
        -DCHIP=OFF
        -DAMIGAOS4=OFF
        -DGBM=OFF
        -DUSE_CCACHE=OFF
        -DUSE_CLOCK=OFF
        -DUSE_ANDROID_LOG=OFF
        -DEGL_WRAPPER=OFF
        -DGLX_STUBS=OFF
        "-DCMAKE_ARCHIVE_OUTPUT_DIRECTORY_RELEASE=${GL4ES_ARCHIVE_DIR}"
)

vcpkg_cmake_build(TARGET GL)

set(GL4ES_ARCHIVE "${GL4ES_ARCHIVE_DIR}/libGL.a")
if(NOT EXISTS "${GL4ES_ARCHIVE}")
    message(FATAL_ERROR "GL4ES produced no static archive at ${GL4ES_ARCHIVE}.")
endif()

# The STATICLIB branch has no upstream install rules. Preserve the complete
# public include tree, while also providing the include/gl4es layout consumed
# by OpenMW's manual initialization adapter.
file(INSTALL "${GL4ES_ARCHIVE}" DESTINATION "${CURRENT_PACKAGES_DIR}/lib")
file(COPY "${SOURCE_PATH}/include/" DESTINATION "${CURRENT_PACKAGES_DIR}/include")
file(MAKE_DIRECTORY "${CURRENT_PACKAGES_DIR}/include/gl4es")
file(INSTALL
    "${SOURCE_PATH}/include/gl4esinit.h"
    "${SOURCE_PATH}/include/gl4eshint.h"
    DESTINATION "${CURRENT_PACKAGES_DIR}/include/gl4es"
)

file(INSTALL
    "${CMAKE_CURRENT_LIST_DIR}/gl4es-config.cmake"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
)

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug"
    "${CURRENT_PACKAGES_DIR}/bin"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
