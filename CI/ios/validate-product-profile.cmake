cmake_minimum_required(VERSION 3.25)

if(NOT CMAKE_HOST_SYSTEM_NAME STREQUAL "Darwin")
    message(FATAL_ERROR "The iOS product profile contract runs on macOS")
endif()

set(repo_root "${CMAKE_CURRENT_LIST_DIR}/../..")
set(contract_prefix "${repo_root}/build/ios-profile-contract-prefix")
file(MAKE_DIRECTORY "${contract_prefix}")

# Exercise the profile as an included CMake module without attempting to
# resolve the not-yet-complete phase 2 dependency graph.
set(OPENMW_IOS TRUE)
set(CMAKE_SYSTEM_NAME iOS)
set(CMAKE_GENERATOR Xcode)
set(CMAKE_OSX_SYSROOT iphoneos)
set(CMAKE_OSX_ARCHITECTURES arm64)
set(CMAKE_OSX_DEPLOYMENT_TARGET 16.4)
set(OPENMW_IOS_DEPS_ROOT "${contract_prefix}" CACHE PATH "" FORCE)
include("${repo_root}/cmake/OpenMWIOSProfile.cmake")

foreach(option IN ITEMS
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
        DEPLOY_QT_TRANSLATIONS
        USE_LUAJIT)
    if(${option})
        message(FATAL_ERROR "${option} must be OFF in the iOS product profile")
    endif()
endforeach()

if(NOT BUILD_OPENMW)
    message(FATAL_ERROR "BUILD_OPENMW must be ON in the iOS product profile")
endif()

foreach(option IN ITEMS
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
    if(NOT ${option})
        message(FATAL_ERROR "${option} must be ON in the iOS product profile")
    endif()
endforeach()

if(NOT CMAKE_FIND_ROOT_PATH_MODE_PROGRAM STREQUAL "NEVER" OR
        NOT CMAKE_FIND_ROOT_PATH_MODE_LIBRARY STREQUAL "ONLY" OR
        NOT CMAKE_FIND_ROOT_PATH_MODE_INCLUDE STREQUAL "ONLY" OR
        NOT CMAKE_FIND_ROOT_PATH_MODE_PACKAGE STREQUAL "ONLY")
    message(FATAL_ERROR "The iOS dependency root isolation contract changed")
endif()

message(STATUS "Validated the pruned static OpenMW iOS product profile")
