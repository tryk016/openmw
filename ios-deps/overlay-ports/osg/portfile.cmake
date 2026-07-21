if(NOT VCPKG_TARGET_IS_IOS OR NOT VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
    message(FATAL_ERROR "The OpenMW osg overlay supports only arm64 iOS targets.")
endif()
if(NOT VCPKG_BUILD_TYPE STREQUAL "release")
    message(FATAL_ERROR "The OpenMW osg overlay requires the release-only project triplets.")
endif()
if(NOT VCPKG_OSX_DEPLOYMENT_TARGET OR VCPKG_OSX_DEPLOYMENT_TARGET VERSION_LESS "16.4")
    message(FATAL_ERROR "The OpenMW osg overlay requires iOS 16.4 or newer.")
endif()
if(NOT VCPKG_OSX_SYSROOT MATCHES "^(iphoneos|iphonesimulator)$")
    message(FATAL_ERROR "VCPKG_OSX_SYSROOT must be iphoneos or iphonesimulator.")
endif()

vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_download_distfile(ARCHIVE
    URLS "https://codeload.github.com/OpenMW/osg/tar.gz/01cc2b585c8456a4ff843066b7e1a8715558289f"
    FILENAME "openmw-osg-01cc2b585c8456a4ff843066b7e1a8715558289f.tar.gz"
    # SHA256: 5727b3e23fa376f7dd41b646e46a7c303ae710a3d250ab489ef5b0672cf355c3
    SHA512 540450c53a92a421f2cf7e10d02053b89abf671242dd3ccdea4401da00063d329226c3acd9e4b182ffb650d67dde2aba29575987448af5f001bcb9be5db5a551
)

vcpkg_extract_source_archive(
    SOURCE_PATH
    ARCHIVE "${ARCHIVE}"
    PATCHES
        ios-modern-gl4es.patch
        ios-minimal-targets.patch
        static-exports.patch
)

# Prefer CMake's maintained FindFreetype module and imported target.
file(REMOVE "${SOURCE_PATH}/CMakeModules/FindFreetype.cmake")

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DBUILD_OSG_APPLICATIONS=OFF
        -DBUILD_OSG_EXAMPLES=OFF
        -DBUILD_OSG_PACKAGES=OFF
        -DBUILD_DOCUMENTATION=OFF
        -DBUILD_OSG_DEPRECATED_SERIALIZERS=ON
        -DBUILD_OSG_PLUGINS_BY_DEFAULT=OFF
        -DBUILD_OSG_PLUGIN_BMP=ON
        -DBUILD_OSG_PLUGIN_DDS=ON
        -DBUILD_OSG_PLUGIN_FREETYPE=ON
        -DBUILD_OSG_PLUGIN_JPEG=ON
        -DBUILD_OSG_PLUGIN_OSG=ON
        -DBUILD_OSG_PLUGIN_PNG=ON
        -DBUILD_OSG_PLUGIN_TGA=ON
        -DBUILD_OSG_PLUGIN_DAE=OFF
        -DDYNAMIC_OPENSCENEGRAPH=OFF
        -DDYNAMIC_OPENTHREADS=OFF
        -DOPENGL_PROFILE=GL2
        -DOSG_BUILD_PLATFORM_IPHONE=ON
        -DOSG_COMPILE_FRAMEWORKS=OFF
        -DOSG_FIND_3RD_PARTY_DEPS=OFF
        -DOSG_GL_LIBRARY_STATIC=OFF
        -DOSG_TEXT_USE_FONTCONFIG=OFF
        -DOSG_USE_LOCAL_LUA_SOURCE=OFF
        -DOSG_WINDOWING_SYSTEM=None
        -DCMAKE_CXX_STANDARD=11
        -DCMAKE_POLICY_DEFAULT_CMP0057=NEW
        -DCMAKE_REQUIRE_FIND_PACKAGE_Freetype=ON
        -DCMAKE_REQUIRE_FIND_PACKAGE_JPEG=ON
        -DCMAKE_REQUIRE_FIND_PACKAGE_PNG=ON
        -DCMAKE_REQUIRE_FIND_PACKAGE_ZLIB=ON
        -DCMAKE_DISABLE_FIND_PACKAGE_Asio=ON
        -DCMAKE_DISABLE_FIND_PACKAGE_AVFoundation=ON
        -DCMAKE_DISABLE_FIND_PACKAGE_COLLADA=ON
        -DCMAKE_DISABLE_FIND_PACKAGE_CURL=ON
        -DCMAKE_DISABLE_FIND_PACKAGE_DCMTK=ON
        -DCMAKE_DISABLE_FIND_PACKAGE_DirectInput=ON
        -DCMAKE_DISABLE_FIND_PACKAGE_DirectShow=ON
        -DCMAKE_DISABLE_FIND_PACKAGE_EGL=ON
        -DCMAKE_DISABLE_FIND_PACKAGE_FBX=ON
        -DCMAKE_DISABLE_FIND_PACKAGE_FFmpeg=ON
        -DCMAKE_DISABLE_FIND_PACKAGE_GDAL=ON
        -DCMAKE_DISABLE_FIND_PACKAGE_GIFLIB=ON
        -DCMAKE_DISABLE_FIND_PACKAGE_GLIB=ON
        -DCMAKE_DISABLE_FIND_PACKAGE_GTA=ON
        -DCMAKE_DISABLE_FIND_PACKAGE_GStreamer=ON
        -DCMAKE_DISABLE_FIND_PACKAGE_GtkGl=ON
        -DCMAKE_DISABLE_FIND_PACKAGE_Inventor=ON
        -DCMAKE_DISABLE_FIND_PACKAGE_Jasper=ON
        -DCMAKE_DISABLE_FIND_PACKAGE_LIBLAS=ON
        -DCMAKE_DISABLE_FIND_PACKAGE_LibVNCServer=ON
        -DCMAKE_DISABLE_FIND_PACKAGE_Lua51=ON
        -DCMAKE_DISABLE_FIND_PACKAGE_Lua52=ON
        -DCMAKE_DISABLE_FIND_PACKAGE_NVTT=ON
        -DCMAKE_DISABLE_FIND_PACKAGE_OpenCascade=ON
        -DCMAKE_DISABLE_FIND_PACKAGE_OpenEXR=ON
        -DCMAKE_DISABLE_FIND_PACKAGE_Poppler-glib=ON
        -DCMAKE_DISABLE_FIND_PACKAGE_QTKit=ON
        -DCMAKE_DISABLE_FIND_PACKAGE_QuickTime=ON
        -DCMAKE_DISABLE_FIND_PACKAGE_RSVG=ON
        -DCMAKE_DISABLE_FIND_PACKAGE_SDL=ON
        -DCMAKE_DISABLE_FIND_PACKAGE_SDL2=ON
        -DCMAKE_DISABLE_FIND_PACKAGE_TIFF=ON
        -DCMAKE_DISABLE_FIND_PACKAGE_X11=ON
        -DCMAKE_DISABLE_FIND_PACKAGE_ZeroConf=ON
        -DCMAKE_DISABLE_FIND_PACKAGE_ilmbase=ON
)

vcpkg_cmake_install()

file(MAKE_DIRECTORY "${CURRENT_PACKAGES_DIR}/share/unofficial-osg")
configure_file(
    "${CMAKE_CURRENT_LIST_DIR}/unofficial-osg-config.cmake"
    "${CURRENT_PACKAGES_DIR}/share/unofficial-osg/unofficial-osg-config.cmake"
    COPYONLY
)
include(CMakePackageConfigHelpers)
write_basic_package_version_file(
    "${CURRENT_PACKAGES_DIR}/share/unofficial-osg/unofficial-osg-config-version.cmake"
    VERSION 3.6.5
    COMPATIBILITY ExactVersion
)
vcpkg_cmake_config_fixup(
    PACKAGE_NAME unofficial-osg
    CONFIG_PATH share/unofficial-osg
)

file(APPEND "${CURRENT_PACKAGES_DIR}/include/osg/Config"
    "#ifndef OSG_LIBRARY_STATIC\n#define OSG_LIBRARY_STATIC 1\n#endif\n")

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug"
    "${CURRENT_PACKAGES_DIR}/bin"
    "${CURRENT_PACKAGES_DIR}/lib/pkgconfig"
)

set(expected_archives
    "${CURRENT_PACKAGES_DIR}/lib/libOpenThreads.a"
    "${CURRENT_PACKAGES_DIR}/lib/libosg.a"
    "${CURRENT_PACKAGES_DIR}/lib/libosgAnimation.a"
    "${CURRENT_PACKAGES_DIR}/lib/libosgDB.a"
    "${CURRENT_PACKAGES_DIR}/lib/libosgFX.a"
    "${CURRENT_PACKAGES_DIR}/lib/libosgGA.a"
    "${CURRENT_PACKAGES_DIR}/lib/libosgParticle.a"
    "${CURRENT_PACKAGES_DIR}/lib/libosgShadow.a"
    "${CURRENT_PACKAGES_DIR}/lib/libosgSim.a"
    "${CURRENT_PACKAGES_DIR}/lib/libosgText.a"
    "${CURRENT_PACKAGES_DIR}/lib/libosgUtil.a"
    "${CURRENT_PACKAGES_DIR}/lib/libosgViewer.a"
    "${CURRENT_PACKAGES_DIR}/lib/osgPlugins-3.6.5/libosgdb_bmp.a"
    "${CURRENT_PACKAGES_DIR}/lib/osgPlugins-3.6.5/libosgdb_dds.a"
    "${CURRENT_PACKAGES_DIR}/lib/osgPlugins-3.6.5/libosgdb_deprecated_osg.a"
    "${CURRENT_PACKAGES_DIR}/lib/osgPlugins-3.6.5/libosgdb_freetype.a"
    "${CURRENT_PACKAGES_DIR}/lib/osgPlugins-3.6.5/libosgdb_jpeg.a"
    "${CURRENT_PACKAGES_DIR}/lib/osgPlugins-3.6.5/libosgdb_osg.a"
    "${CURRENT_PACKAGES_DIR}/lib/osgPlugins-3.6.5/libosgdb_png.a"
    "${CURRENT_PACKAGES_DIR}/lib/osgPlugins-3.6.5/libosgdb_serializers_osg.a"
    "${CURRENT_PACKAGES_DIR}/lib/osgPlugins-3.6.5/libosgdb_tga.a"
)
file(GLOB_RECURSE actual_archives LIST_DIRECTORIES false "${CURRENT_PACKAGES_DIR}/lib/*.a")
list(SORT expected_archives)
list(SORT actual_archives)
if(NOT "${actual_archives}" STREQUAL "${expected_archives}")
    message(FATAL_ERROR
        "Unexpected OSG archive set.\nExpected: ${expected_archives}\nActual: ${actual_archives}")
endif()

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE.txt")
