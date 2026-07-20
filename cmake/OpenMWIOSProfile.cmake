# OpenMW's full iOS product profile.  OPENMW_IOS is derived by the top-level
# project from CMAKE_SYSTEM_NAME, so this file must not be included directly by
# desktop builds.
if(NOT OPENMW_IOS OR NOT CMAKE_SYSTEM_NAME STREQUAL "iOS")
    message(FATAL_ERROR "OpenMWIOSProfile.cmake requires CMAKE_SYSTEM_NAME=iOS")
endif()

if(NOT CMAKE_HOST_SYSTEM_NAME STREQUAL "Darwin")
    message(FATAL_ERROR "The OpenMW iOS product must be configured on macOS with Xcode installed")
endif()
if(NOT CMAKE_GENERATOR STREQUAL "Xcode")
    message(FATAL_ERROR "The OpenMW iOS product requires the Xcode generator")
endif()

if(NOT CMAKE_OSX_DEPLOYMENT_TARGET)
    set(CMAKE_OSX_DEPLOYMENT_TARGET "16.4" CACHE STRING "Minimum supported iOS version" FORCE)
endif()
if(CMAKE_OSX_DEPLOYMENT_TARGET VERSION_LESS "16.4")
    message(FATAL_ERROR "OpenMW iOS requires a deployment target of 16.4 or newer")
endif()

if(CMAKE_OSX_ARCHITECTURES AND NOT CMAKE_OSX_ARCHITECTURES STREQUAL "arm64")
    message(FATAL_ERROR "OpenMW iOS supports only the arm64 device and simulator slices")
endif()

set(OPENMW_IOS_DEPS_ROOT "" CACHE PATH
    "Static dependency prefix for the selected iOS SDK")
if(OPENMW_IOS_DEPS_ROOT STREQUAL "")
    message(FATAL_ERROR
        "OPENMW_IOS_DEPS_ROOT must point at the matching phase 2 static prefix")
endif()
if(NOT IS_DIRECTORY "${OPENMW_IOS_DEPS_ROOT}")
    message(FATAL_ERROR
        "The selected iOS dependency prefix does not exist: "
        "${OPENMW_IOS_DEPS_ROOT}")
endif()

list(PREPEND CMAKE_PREFIX_PATH "${OPENMW_IOS_DEPS_ROOT}")
list(PREPEND CMAKE_FIND_ROOT_PATH "${OPENMW_IOS_DEPS_ROOT}")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# The fork is an iOS product, not a collection of desktop utilities.  Keep the
# one engine entry point and make accidental Qt, host-tool or test enablement a
# configure-time impossibility for this profile.
set(BUILD_OPENMW ON CACHE BOOL "Build OpenMW" FORCE)
foreach(_openmw_ios_disabled_option IN ITEMS
        BUILD_LAUNCHER
        BUILD_WIZARD
        BUILD_MWINIIMPORTER
        BUILD_OPENCS
        BUILD_ESSIMPORTER
        BUILD_BSATOOL
        BUILD_ESMTOOL
        BUILD_NIFTEST
        BUILD_DOCS
        BUILD_WITH_CODE_COVERAGE
        BUILD_COMPONENTS_TESTS
        BUILD_BENCHMARKS
        BUILD_NAVMESHTOOL
        BUILD_BULLETOBJECTTOOL
        BUILD_OPENCS_TESTS
        BUILD_OPENMW_TESTS
        DEPLOY_QT_TRANSLATIONS)
    set(${_openmw_ios_disabled_option} OFF CACHE BOOL "Disabled by the OpenMW iOS product profile" FORCE)
endforeach()
unset(_openmw_ios_disabled_option)

# The product consumes only the phase 2 static prefixes. It must not fall back
# to host packages or the root project's FetchContent copies.
foreach(_openmw_ios_enabled_option IN ITEMS
        OPENMW_USE_SYSTEM_BULLET
        OPENMW_USE_SYSTEM_OSG
        OPENMW_USE_SYSTEM_MYGUI
        OPENMW_USE_SYSTEM_RECASTNAVIGATION
        OPENMW_USE_SYSTEM_SQLITE3
        OPENMW_USE_SYSTEM_ICU
        OPENMW_USE_SYSTEM_YAML_CPP
        BULLET_STATIC
        OSG_STATIC
        MYGUI_STATIC
        RECASTNAVIGATION_STATIC
        YAML_CPP_STATIC)
    set(${_openmw_ios_enabled_option} ON CACHE BOOL
        "Required by the OpenMW iOS static dependency profile" FORCE)
endforeach()
unset(_openmw_ios_enabled_option)
set(USE_LUAJIT OFF CACHE BOOL "iOS uses the PUC Lua interpreter" FORCE)

message(STATUS
    "OpenMW iOS product profile: sdk=${CMAKE_OSX_SYSROOT}, "
    "arch=${CMAKE_OSX_ARCHITECTURES}, minimum=${CMAKE_OSX_DEPLOYMENT_TARGET}")
