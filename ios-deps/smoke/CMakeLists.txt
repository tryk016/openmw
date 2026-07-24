cmake_minimum_required(VERSION 3.25)
project(OpenMWIOSDepsSmoke VERSION 0.1.0 LANGUAGES C CXX OBJCXX)

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

# BoostConfig resolves every modular dependency with nested find_package calls.
# Keep the entire lookup graph anchored to the verified static prefix, while
# retaining the exact path restriction for the top-level package itself.
block()
    list(PREPEND CMAKE_PREFIX_PATH "${IOS_DEPS_PREFIX}")
    set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE NEVER)
    find_package(Boost 1.90.0 CONFIG REQUIRED
        COMPONENTS geometry iostreams program_options
        PATHS "${IOS_DEPS_PREFIX}/share/boost"
        NO_DEFAULT_PATH
        NO_CMAKE_FIND_ROOT_PATH)
endblock()
foreach(boost_target IN ITEMS
        Boost::geometry
        Boost::iostreams
        Boost::program_options)
    if(NOT TARGET "${boost_target}")
        message(FATAL_ERROR
            "The locked Boost package has no ${boost_target} target")
    endif()
endforeach()

set(bullet_collision_archive
    "${IOS_DEPS_PREFIX}/lib/libBulletCollision.a")
set(bullet_linear_math_archive
    "${IOS_DEPS_PREFIX}/lib/libLinearMath.a")
foreach(bullet_archive IN ITEMS
        "${bullet_collision_archive}"
        "${bullet_linear_math_archive}")
    if(NOT EXISTS "${bullet_archive}")
        message(FATAL_ERROR
            "A locked minimal Bullet archive is missing: ${bullet_archive}")
    endif()
endforeach()
find_package(Bullet 3.17 EXACT CONFIG REQUIRED
    COMPONENTS BulletCollision LinearMath
    PATHS "${IOS_DEPS_PREFIX}/share/bullet"
    NO_DEFAULT_PATH
    NO_CMAKE_FIND_ROOT_PATH)
foreach(bullet_target IN ITEMS BulletCollision LinearMath)
    if(NOT TARGET "${bullet_target}")
        message(FATAL_ERROR
            "The locked Bullet package has no ${bullet_target} target")
    endif()
    get_target_property(bullet_target_type "${bullet_target}" TYPE)
    get_target_property(bullet_target_location
        "${bullet_target}" IMPORTED_LOCATION_RELEASE)
    if(NOT bullet_target_type STREQUAL "STATIC_LIBRARY")
        message(FATAL_ERROR
            "${bullet_target} is not an imported static library")
    endif()
    if(bullet_target STREQUAL "BulletCollision")
        set(expected_bullet_location "${bullet_collision_archive}")
    else()
        set(expected_bullet_location "${bullet_linear_math_archive}")
    endif()
    if(NOT bullet_target_location STREQUAL expected_bullet_location)
        message(FATAL_ERROR
            "${bullet_target} does not resolve to the locked archive")
    endif()
endforeach()
foreach(forbidden_bullet_component IN ITEMS
        BulletDynamics
        BulletSoftBody
        Bullet3Common
        BulletInverseDynamics)
    if(TARGET "${forbidden_bullet_component}"
            OR "${BULLET_LIBRARIES}" MATCHES "${forbidden_bullet_component}")
        message(FATAL_ERROR
            "Unexpected Bullet component: ${forbidden_bullet_component}")
    endif()
endforeach()

set(recast_archives
    "${IOS_DEPS_PREFIX}/lib/libRecast.a"
    "${IOS_DEPS_PREFIX}/lib/libDetour.a"
    "${IOS_DEPS_PREFIX}/lib/libDetourTileCache.a"
    "${IOS_DEPS_PREFIX}/lib/libDebugUtils.a")
foreach(recast_archive IN LISTS recast_archives)
    if(NOT EXISTS "${recast_archive}")
        message(FATAL_ERROR
            "A locked navigation archive is missing: ${recast_archive}")
    endif()
endforeach()
find_package(recastnavigation 1.6.0 EXACT CONFIG REQUIRED
    PATHS "${IOS_DEPS_PREFIX}/share/recastnavigation"
    NO_DEFAULT_PATH
    NO_CMAKE_FIND_ROOT_PATH)
foreach(recast_target IN ITEMS Recast Detour DetourTileCache DebugUtils)
    set(qualified_recast_target "RecastNavigation::${recast_target}")
    if(NOT TARGET "${qualified_recast_target}")
        message(FATAL_ERROR
            "The locked navigation package has no ${qualified_recast_target} target")
    endif()
    get_target_property(recast_target_type
        "${qualified_recast_target}" TYPE)
    get_target_property(recast_target_location
        "${qualified_recast_target}" IMPORTED_LOCATION_RELEASE)
    if(NOT recast_target_type STREQUAL "STATIC_LIBRARY")
        message(FATAL_ERROR
            "${qualified_recast_target} is not an imported static library")
    endif()
    if(NOT recast_target_location STREQUAL
            "${IOS_DEPS_PREFIX}/lib/lib${recast_target}.a")
        message(FATAL_ERROR
            "${qualified_recast_target} does not resolve to the locked archive")
    endif()
endforeach()
if(TARGET RecastNavigation::DetourCrowd
        OR EXISTS "${IOS_DEPS_PREFIX}/lib/libDetourCrowd.a")
    message(FATAL_ERROR "DetourCrowd leaked into the navigation foundation")
endif()

set(yaml_archive "${IOS_DEPS_PREFIX}/lib/libyaml-cpp.a")
if(NOT EXISTS "${yaml_archive}")
    message(FATAL_ERROR
        "The locked yaml-cpp archive is missing: ${yaml_archive}")
endif()
find_package(yaml-cpp 0.8.0 EXACT CONFIG REQUIRED
    PATHS "${IOS_DEPS_PREFIX}/share/yaml-cpp"
    NO_DEFAULT_PATH
    NO_CMAKE_FIND_ROOT_PATH)
if(NOT TARGET yaml-cpp::yaml-cpp)
    message(FATAL_ERROR
        "The locked yaml-cpp package has no yaml-cpp::yaml-cpp target")
endif()
if(NOT "${yaml-cpp_VERSION}" STREQUAL "0.8.0")
    message(FATAL_ERROR
        "Unexpected yaml-cpp package version: ${yaml-cpp_VERSION}")
endif()
get_target_property(yaml_target_type yaml-cpp::yaml-cpp TYPE)
get_target_property(yaml_location
    yaml-cpp::yaml-cpp IMPORTED_LOCATION_RELEASE)
if(NOT yaml_target_type STREQUAL "STATIC_LIBRARY"
        OR NOT yaml_location STREQUAL yaml_archive)
    message(FATAL_ERROR
        "yaml-cpp did not resolve to the locked static archive")
endif()

set(sqlite_archive "${IOS_DEPS_PREFIX}/lib/libsqlite3.a")
if(NOT EXISTS "${sqlite_archive}")
    message(FATAL_ERROR
        "The locked SQLite archive is missing: ${sqlite_archive}")
endif()
set(SQLite3_INCLUDE_DIR "${IOS_DEPS_PREFIX}/include")
set(SQLite3_LIBRARY "${sqlite_archive}")
find_package(SQLite3 3.51.2 EXACT MODULE REQUIRED)
if(NOT SQLite3_VERSION STREQUAL "3.51.2"
        OR NOT SQLite3_INCLUDE_DIRS STREQUAL SQLite3_INCLUDE_DIR
        OR NOT SQLite3_LIBRARIES STREQUAL sqlite_archive
        OR NOT TARGET SQLite::SQLite3)
    message(FATAL_ERROR
        "SQLite did not resolve exactly from the locked static prefix")
endif()
get_target_property(sqlite_location SQLite::SQLite3 IMPORTED_LOCATION)
if(NOT sqlite_location STREQUAL sqlite_archive)
    message(FATAL_ERROR
        "SQLite imported target does not use ${sqlite_archive}")
endif()
if(NOT TARGET SQLite3::SQLite3)
    add_library(SQLite3::SQLite3 ALIAS SQLite::SQLite3)
endif()
find_package(Threads REQUIRED)

find_package(unofficial-lua CONFIG REQUIRED
    PATHS "${IOS_DEPS_PREFIX}/share/unofficial-lua"
    NO_DEFAULT_PATH
    NO_CMAKE_FIND_ROOT_PATH)
if(NOT TARGET unofficial::lua::lua)
    message(FATAL_ERROR
        "The locked Lua package has no unofficial::lua::lua target")
endif()
get_target_property(lua_target_type unofficial::lua::lua TYPE)
get_target_property(lua_target_location
    unofficial::lua::lua IMPORTED_LOCATION_RELEASE)
if(NOT lua_target_type STREQUAL "STATIC_LIBRARY" OR
        NOT lua_target_location STREQUAL "${IOS_DEPS_PREFIX}/lib/liblua.a")
    message(FATAL_ERROR "Lua did not resolve to the locked static archive")
endif()

set(ICU_ROOT "${IOS_DEPS_PREFIX}")
set(ICU_INCLUDE_DIR "${IOS_DEPS_PREFIX}/include")
foreach(icu_component IN ITEMS DATA UC I18N)
    string(TOLOWER "${icu_component}" icu_component_lower)
    set(ICU_${icu_component}_LIBRARY
        "${IOS_DEPS_PREFIX}/lib/libicu${icu_component_lower}.a")
    set(ICU_${icu_component}_LIBRARY_RELEASE
        "${ICU_${icu_component}_LIBRARY}")
endforeach()
find_package(ICU 70.1 EXACT MODULE REQUIRED COMPONENTS data uc i18n)
if(NOT ICU_VERSION STREQUAL "70.1")
    message(FATAL_ERROR "Unexpected ICU version: ${ICU_VERSION}")
endif()
foreach(icu_component IN ITEMS data uc i18n)
    if(NOT TARGET "ICU::${icu_component}")
        message(FATAL_ERROR
            "The locked ICU package has no ICU::${icu_component} target")
    endif()
endforeach()

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

set(mygui_archive "${IOS_DEPS_PREFIX}/lib/libMyGUIEngineStatic.a")
if(NOT EXISTS "${mygui_archive}")
    message(FATAL_ERROR
        "The locked static MyGUI engine archive is missing: ${mygui_archive}")
endif()
add_library(OpenMWIOS::MyGUI STATIC IMPORTED GLOBAL)
set_target_properties(OpenMWIOS::MyGUI PROPERTIES
    IMPORTED_CONFIGURATIONS RELEASE
    IMPORTED_LOCATION_RELEASE "${mygui_archive}"
    INTERFACE_INCLUDE_DIRECTORIES "${IOS_DEPS_PREFIX}/include/MYGUI"
    INTERFACE_COMPILE_DEFINITIONS
        "MYGUI_STATIC;MYGUI_USE_FREETYPE;MYGUI_DONT_USE_OBSOLETE")
set_property(TARGET OpenMWIOS::MyGUI APPEND PROPERTY
    INTERFACE_LINK_LIBRARIES
        "Freetype::Freetype;PNG::PNG;ZLIB::ZLIB")
get_target_property(mygui_target_type OpenMWIOS::MyGUI TYPE)
get_target_property(mygui_target_location
    OpenMWIOS::MyGUI IMPORTED_LOCATION_RELEASE)
get_target_property(mygui_target_link_interface
    OpenMWIOS::MyGUI INTERFACE_LINK_LIBRARIES)
if(NOT mygui_target_type STREQUAL "STATIC_LIBRARY"
        OR NOT mygui_target_location STREQUAL mygui_archive)
    message(FATAL_ERROR
        "MyGUI did not resolve to the locked static engine archive")
endif()
set(expected_mygui_link_interface
    Freetype::Freetype
    PNG::PNG
    ZLIB::ZLIB)
if(NOT mygui_target_link_interface STREQUAL expected_mygui_link_interface)
    message(FATAL_ERROR
        "MyGUI does not propagate its complete static link interface")
endif()

set(openal_archive "${IOS_DEPS_PREFIX}/lib/libopenal.a")
if(NOT EXISTS "${openal_archive}")
    message(FATAL_ERROR
        "The locked static OpenAL Soft archive is missing: ${openal_archive}")
endif()
find_library(COREAUDIO_FRAMEWORK CoreAudio REQUIRED)
find_library(COREFOUNDATION_FRAMEWORK CoreFoundation REQUIRED)
find_library(AUDIOTOOLBOX_FRAMEWORK AudioToolbox REQUIRED)
add_library(OpenMWIOS::OpenAL STATIC IMPORTED GLOBAL)
set_target_properties(OpenMWIOS::OpenAL PROPERTIES
    IMPORTED_CONFIGURATIONS RELEASE
    IMPORTED_LOCATION_RELEASE "${openal_archive}"
    INTERFACE_INCLUDE_DIRECTORIES "${IOS_DEPS_PREFIX}/include"
    INTERFACE_LINK_LIBRARIES
        "${COREAUDIO_FRAMEWORK};${COREFOUNDATION_FRAMEWORK};${AUDIOTOOLBOX_FRAMEWORK}")

set(ffmpeg_archives
    "${IOS_DEPS_PREFIX}/lib/libavformat.a"
    "${IOS_DEPS_PREFIX}/lib/libavcodec.a"
    "${IOS_DEPS_PREFIX}/lib/libswresample.a"
    "${IOS_DEPS_PREFIX}/lib/libswscale.a"
    "${IOS_DEPS_PREFIX}/lib/libavutil.a")
foreach(ffmpeg_archive IN LISTS ffmpeg_archives)
    if(NOT EXISTS "${ffmpeg_archive}")
        message(FATAL_ERROR
            "A locked minimal FFmpeg archive is missing: ${ffmpeg_archive}")
    endif()
endforeach()
foreach(forbidden_ffmpeg_archive IN ITEMS
        libavdevice.a libavfilter.a libpostproc.a)
    if(EXISTS "${IOS_DEPS_PREFIX}/lib/${forbidden_ffmpeg_archive}")
        message(FATAL_ERROR
            "A forbidden FFmpeg component leaked into the prefix: ${forbidden_ffmpeg_archive}")
    endif()
endforeach()
find_library(COREMEDIA_FRAMEWORK CoreMedia REQUIRED)
find_library(COREVIDEO_FRAMEWORK CoreVideo REQUIRED)
add_library(OpenMWIOS::FFmpeg INTERFACE IMPORTED GLOBAL)
set_target_properties(OpenMWIOS::FFmpeg PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${IOS_DEPS_PREFIX}/include"
    INTERFACE_LINK_LIBRARIES
        "${ffmpeg_archives};${COREFOUNDATION_FRAMEWORK};${COREMEDIA_FRAMEWORK};${COREVIDEO_FRAMEWORK}")

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

# OSG's static exports are deliberately exposed through an unofficial package
# so the iOS fork cannot silently fall back to a system OpenSceneGraph. Its
# nested dependencies resolve only from the same verified prefix.
block()
    list(PREPEND CMAKE_PREFIX_PATH "${IOS_DEPS_PREFIX}")
    set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE NEVER)
    find_package(gl4es CONFIG REQUIRED
        PATHS "${IOS_DEPS_PREFIX}/share/gl4es"
        NO_DEFAULT_PATH
        NO_CMAKE_FIND_ROOT_PATH)
    find_package(unofficial-osg 3.6.5 EXACT CONFIG REQUIRED
        PATHS "${IOS_DEPS_PREFIX}/share/unofficial-osg"
        NO_DEFAULT_PATH
        NO_CMAKE_FIND_ROOT_PATH)
endblock()
if(NOT TARGET gl4es::GL)
    message(FATAL_ERROR "The locked GL4ES package has no gl4es::GL target")
endif()
get_target_property(gl4es_target_type gl4es::GL TYPE)
get_target_property(gl4es_target_location gl4es::GL IMPORTED_LOCATION)
if(NOT gl4es_target_type STREQUAL "STATIC_LIBRARY"
        OR NOT gl4es_target_location STREQUAL
            "${IOS_DEPS_PREFIX}/lib/libGL.a")
    message(FATAL_ERROR "GL4ES did not resolve to the locked static archive")
endif()

set(osg_core_names
    osgAnimation
    osgParticle
    osgFX
    osgShadow
    osgSim
    osgViewer
    osgGA
    osgText
    osgDB
    osgUtil
    osg
    OpenThreads)
set(osg_plugin_names
    osgdb_bmp
    osgdb_dds
    osgdb_deprecated_osg
    osgdb_freetype
    osgdb_jpeg
    osgdb_osg
    osgdb_png
    osgdb_serializers_osg
    osgdb_tga)
set(osg_core_targets)
foreach(osg_name IN LISTS osg_core_names)
    set(osg_target "unofficial::osg::${osg_name}")
    if(NOT TARGET "${osg_target}")
        message(FATAL_ERROR "The locked OSG package has no ${osg_target} target")
    endif()
    get_target_property(osg_target_type "${osg_target}" TYPE)
    get_target_property(osg_target_location
        "${osg_target}" IMPORTED_LOCATION_RELEASE)
    if(NOT osg_target_type STREQUAL "STATIC_LIBRARY"
            OR NOT osg_target_location STREQUAL
                "${IOS_DEPS_PREFIX}/lib/lib${osg_name}.a")
        message(FATAL_ERROR
            "${osg_target} did not resolve to its locked static archive")
    endif()
    list(APPEND osg_core_targets "${osg_target}")
endforeach()

set(osg_plugin_targets)
foreach(osg_name IN LISTS osg_plugin_names)
    set(osg_target "unofficial::osg::${osg_name}")
    if(NOT TARGET "${osg_target}")
        message(FATAL_ERROR "The locked OSG package has no ${osg_target} target")
    endif()
    get_target_property(osg_target_type "${osg_target}" TYPE)
    get_target_property(osg_target_location
        "${osg_target}" IMPORTED_LOCATION_RELEASE)
    if(NOT osg_target_type STREQUAL "STATIC_LIBRARY"
            OR NOT osg_target_location STREQUAL
                "${IOS_DEPS_PREFIX}/lib/osgPlugins-3.6.5/lib${osg_name}.a")
        message(FATAL_ERROR
            "${osg_target} did not resolve to its locked static plugin archive")
    endif()
    list(APPEND osg_plugin_targets "${osg_target}")
endforeach()
if(TARGET unofficial::osg::osgdb_dae
        OR EXISTS "${IOS_DEPS_PREFIX}/lib/osgPlugins-3.6.5/libosgdb_dae.a")
    message(FATAL_ERROR "The DAE plugin leaked into the render foundation")
endif()

add_library(OpenMWIOSRender INTERFACE)
add_library(OpenMWIOS::Render ALIAS OpenMWIOSRender)
target_compile_definitions(OpenMWIOSRender INTERFACE OSG_LIBRARY_STATIC)
target_link_libraries(OpenMWIOSRender INTERFACE
    ${osg_plugin_targets}
    ${osg_core_targets}
    gl4es::GL)
# Apple does not recursively load plugin registration objects from archives.
# Force-load each allowlisted archive separately; -all_load is intentionally
# forbidden because it would conceal accidental plugin growth.
foreach(osg_plugin_target IN LISTS osg_plugin_targets)
    target_link_options(OpenMWIOSRender INTERFACE
        "LINKER:-force_load,$<TARGET_FILE:${osg_plugin_target}>")
endforeach()

find_library(UIKIT_FRAMEWORK UIKit REQUIRED)
find_library(FOUNDATION_FRAMEWORK Foundation REQUIRED)

add_executable(openmw-ios-deps-smoke MACOSX_BUNDLE
    Main.mm
    BulletProbe.cpp
    FFmpegProbe.cpp
    IcuProbe.cpp
    LuaProbe.cpp
    MyGUIProbe.cpp
    OpenALProbe.c
    RecastProbe.cpp
    RenderProbe.cpp
    YamlProbe.cpp
    SQLiteProbe.c)
target_compile_definitions(openmw-ios-deps-smoke PRIVATE
    SDL_MAIN_HANDLED
    OPENMW_IOS_PROBE_NO_MAIN
    OSG_LIBRARY_STATIC)
target_compile_features(openmw-ios-deps-smoke PRIVATE c_std_11 cxx_std_20)
target_link_options(openmw-ios-deps-smoke PRIVATE "LINKER:-ObjC")
target_link_libraries(openmw-ios-deps-smoke PRIVATE
    ZLIB::ZLIB
    "${sdl2_target}"
    lz4::lz4
    Freetype::Freetype
    PNG::PNG
    JPEG::JPEG
    "${turbojpeg_target}"
    BulletCollision
    LinearMath
    RecastNavigation::DebugUtils
    RecastNavigation::Recast
    RecastNavigation::Detour
    RecastNavigation::DetourTileCache
    unofficial::lua::lua
    ICU::i18n
    ICU::uc
    ICU::data
    OpenMWIOS::MyGUI
    OpenMWIOS::OpenAL
    OpenMWIOS::FFmpeg
    OpenMWIOS::Render
    yaml-cpp::yaml-cpp
    SQLite3::SQLite3
    Threads::Threads
    "${CMAKE_DL_LIBS}"
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

add_executable(openmw-ios-render-probe RenderProbe.cpp)
target_compile_definitions(openmw-ios-render-probe PRIVATE
    SDL_MAIN_HANDLED
    OSG_LIBRARY_STATIC)
target_compile_features(openmw-ios-render-probe PRIVATE cxx_std_20)
target_link_libraries(openmw-ios-render-probe PRIVATE
    OpenMWIOS::Render
    "${sdl2_target}")
set_target_properties(openmw-ios-render-probe PROPERTIES
    OUTPUT_NAME "OpenMWRenderProbe"
    XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "NO"
    XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED "NO"
    XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY ""
    XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "16.4")

add_executable(openmw-ios-openal-probe OpenALProbe.c)
target_compile_features(openmw-ios-openal-probe PRIVATE c_std_11)
target_link_libraries(openmw-ios-openal-probe PRIVATE OpenMWIOS::OpenAL)
set_target_properties(openmw-ios-openal-probe PROPERTIES
    OUTPUT_NAME "OpenMWOpenALProbe"
    LINKER_LANGUAGE CXX
    XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "NO"
    XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED "NO"
    XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY ""
    XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "16.4")

add_executable(openmw-ios-ffmpeg-probe FFmpegProbe.cpp)
target_compile_features(openmw-ios-ffmpeg-probe PRIVATE cxx_std_20)
target_link_libraries(openmw-ios-ffmpeg-probe PRIVATE OpenMWIOS::FFmpeg)
set_target_properties(openmw-ios-ffmpeg-probe PROPERTIES
    OUTPUT_NAME "OpenMWFFmpegProbe"
    XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "NO"
    XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED "NO"
    XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY ""
    XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "16.4")

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

add_executable(openmw-ios-boost-probe BoostProbe.cpp)
target_compile_features(openmw-ios-boost-probe PRIVATE cxx_std_20)
target_link_libraries(openmw-ios-boost-probe PRIVATE
    Boost::geometry
    Boost::iostreams
    Boost::program_options)
set_target_properties(openmw-ios-boost-probe PROPERTIES
    OUTPUT_NAME "OpenMWBoostProbe"
    XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "NO"
    XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED "NO"
    XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY ""
    XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "16.4")

add_executable(openmw-ios-yaml-probe YamlProbe.cpp)
target_compile_features(openmw-ios-yaml-probe PRIVATE cxx_std_20)
target_link_libraries(openmw-ios-yaml-probe PRIVATE yaml-cpp::yaml-cpp)
set_target_properties(openmw-ios-yaml-probe PROPERTIES
    OUTPUT_NAME "OpenMWYAMLProbe"
    XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "NO"
    XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED "NO"
    XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY ""
    XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "16.4")

add_executable(openmw-ios-bullet-probe BulletProbe.cpp)
target_compile_features(openmw-ios-bullet-probe PRIVATE cxx_std_20)
target_link_libraries(openmw-ios-bullet-probe PRIVATE
    BulletCollision
    LinearMath
    Threads::Threads)
set_target_properties(openmw-ios-bullet-probe PROPERTIES
    OUTPUT_NAME "OpenMWBulletProbe"
    XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "NO"
    XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED "NO"
    XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY ""
    XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "16.4")

add_executable(openmw-ios-recast-probe RecastProbe.cpp)
target_compile_features(openmw-ios-recast-probe PRIVATE cxx_std_20)
target_link_libraries(openmw-ios-recast-probe PRIVATE
    RecastNavigation::DebugUtils
    RecastNavigation::Recast
    RecastNavigation::Detour
    RecastNavigation::DetourTileCache)
set_target_properties(openmw-ios-recast-probe PROPERTIES
    OUTPUT_NAME "OpenMWRecastProbe"
    XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "NO"
    XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED "NO"
    XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY ""
    XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "16.4")

add_executable(openmw-ios-sqlite-probe SQLiteProbe.c)
target_compile_features(openmw-ios-sqlite-probe PRIVATE c_std_11)
target_link_libraries(openmw-ios-sqlite-probe PRIVATE
    SQLite3::SQLite3
    Threads::Threads
    "${CMAKE_DL_LIBS}")
set_target_properties(openmw-ios-sqlite-probe PROPERTIES
    OUTPUT_NAME "OpenMWSQLiteProbe"
    XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "NO"
    XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED "NO"
    XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY ""
    XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "16.4")

add_executable(openmw-ios-lua-probe LuaProbe.cpp)
target_compile_features(openmw-ios-lua-probe PRIVATE cxx_std_20)
target_link_libraries(openmw-ios-lua-probe PRIVATE unofficial::lua::lua)
set_target_properties(openmw-ios-lua-probe PROPERTIES
    OUTPUT_NAME "OpenMWLuaProbe"
    XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "NO"
    XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED "NO"
    XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY ""
    XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "16.4")

add_executable(openmw-ios-icu-probe IcuProbe.cpp)
target_compile_features(openmw-ios-icu-probe PRIVATE cxx_std_20)
target_link_libraries(openmw-ios-icu-probe PRIVATE
    ICU::i18n
    ICU::uc
    ICU::data)
set_target_properties(openmw-ios-icu-probe PROPERTIES
    OUTPUT_NAME "OpenMWICUProbe"
    XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "NO"
    XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED "NO"
    XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY ""
    XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "16.4")

add_executable(openmw-ios-mygui-probe MyGUIProbe.cpp)
target_compile_features(openmw-ios-mygui-probe PRIVATE cxx_std_20)
target_link_libraries(openmw-ios-mygui-probe PRIVATE OpenMWIOS::MyGUI)
set_target_properties(openmw-ios-mygui-probe PROPERTIES
    OUTPUT_NAME "OpenMWMyGUIProbe"
    XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "NO"
    XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED "NO"
    XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY ""
    XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "16.4")
