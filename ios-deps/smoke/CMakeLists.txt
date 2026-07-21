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

find_library(UIKIT_FRAMEWORK UIKit REQUIRED)
find_library(FOUNDATION_FRAMEWORK Foundation REQUIRED)

add_executable(openmw-ios-deps-smoke MACOSX_BUNDLE
    Main.mm
    BulletProbe.cpp
    YamlProbe.cpp
    SQLiteProbe.c)
target_compile_definitions(openmw-ios-deps-smoke PRIVATE
    SDL_MAIN_HANDLED
    OPENMW_IOS_PROBE_NO_MAIN)
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
