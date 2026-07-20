cmake_minimum_required(VERSION 3.25)

if(NOT DEFINED LOCK_FILE)
    set(LOCK_FILE
        "${CMAKE_CURRENT_LIST_DIR}/../../../ios-deps/dependencies.lock.json")
endif()

if(NOT EXISTS "${LOCK_FILE}")
    message(FATAL_ERROR "Dependency lock file does not exist: ${LOCK_FILE}")
endif()

file(READ "${LOCK_FILE}" lock)
string(JSON schema ERROR_VARIABLE json_error GET "${lock}" schema)
if(json_error)
    message(FATAL_ERROR "Invalid dependency lock JSON: ${json_error}")
endif()
if(NOT schema EQUAL 1)
    message(FATAL_ERROR "Unsupported dependency lock schema: ${schema}")
endif()

string(JSON deployment_target GET "${lock}" deployment_target)
if(NOT deployment_target STREQUAL "16.4")
    message(FATAL_ERROR "The dependency deployment target must remain 16.4")
endif()

string(JSON artifact_format GET "${lock}" artifact_format)
if(NOT artifact_format STREQUAL "separate-static-prefixes")
    message(FATAL_ERROR
        "Only separate static iphoneos/iphonesimulator prefixes are supported")
endif()

string(JSON dependency_count LENGTH "${lock}" dependencies)
if(dependency_count LESS 1)
    message(FATAL_ERROR "The dependency lock must contain at least one entry")
endif()

set(names)
math(EXPR last_dependency "${dependency_count} - 1")
foreach(index RANGE 0 ${last_dependency})
    foreach(field name version phase group archive url sha256 source_root license license_files)
        string(JSON value ERROR_VARIABLE field_error
            GET "${lock}" dependencies ${index} ${field})
        if(field_error)
            message(FATAL_ERROR
                "dependencies[${index}] is missing required field '${field}'")
        endif()
    endforeach()

    string(JSON name GET "${lock}" dependencies ${index} name)
    if(name IN_LIST names)
        message(FATAL_ERROR "Duplicate dependency name: ${name}")
    endif()
    list(APPEND names "${name}")

    if(name STREQUAL "vcpkg")
        string(JSON revision ERROR_VARIABLE revision_error
            GET "${lock}" dependencies ${index} revision)
        string(LENGTH "${revision}" revision_length)
        if(revision_error OR NOT revision_length EQUAL 40 OR
                NOT revision MATCHES "^[0-9a-f]+$")
            message(FATAL_ERROR
                "vcpkg must be pinned to a full lowercase Git commit")
        endif()
    endif()

    string(JSON phase GET "${lock}" dependencies ${index} phase)
    if(NOT phase EQUAL 2 AND NOT phase EQUAL 4)
        message(FATAL_ERROR "${name}: phase must be 2 or 4")
    endif()

    string(JSON group GET "${lock}" dependencies ${index} group)
    if(NOT group MATCHES "^(base|language|multimedia|render)$")
        message(FATAL_ERROR "${name}: unsupported dependency group '${group}'")
    endif()

    string(JSON url GET "${lock}" dependencies ${index} url)
    if(NOT url MATCHES "^https://")
        message(FATAL_ERROR "${name}: source URL must use HTTPS")
    endif()

    string(JSON archive GET "${lock}" dependencies ${index} archive)
    if(archive MATCHES "[/\\\\]" OR archive MATCHES "^\\.")
        message(FATAL_ERROR "${name}: archive must be a safe base filename")
    endif()

    string(JSON source_root GET "${lock}" dependencies ${index} source_root)
    if(source_root MATCHES "[/\\\\]" OR source_root MATCHES "^\\.")
        message(FATAL_ERROR "${name}: source_root must be one directory name")
    endif()
    if(url MATCHES "/(master|main)(/|$)" OR url MATCHES "refs/heads/")
        message(FATAL_ERROR "${name}: source URL points at a mutable branch")
    endif()

    string(JSON sha256 GET "${lock}" dependencies ${index} sha256)
    string(LENGTH "${sha256}" hash_length)
    if(NOT hash_length EQUAL 64 OR NOT sha256 MATCHES "^[0-9a-f]+$")
        message(FATAL_ERROR "${name}: sha256 must be 64 lowercase hex digits")
    endif()

    string(JSON license GET "${lock}" dependencies ${index} license)
    if(license STREQUAL "")
        message(FATAL_ERROR "${name}: SPDX license expression is empty")
    endif()

    string(JSON license_count LENGTH "${lock}" dependencies ${index} license_files)
    if(license_count EQUAL 0)
        string(JSON notice ERROR_VARIABLE notice_error
            GET "${lock}" dependencies ${index} license_notice)
        if(notice_error OR notice STREQUAL "")
            message(FATAL_ERROR
                "${name}: empty license_files requires license_notice")
        endif()
    endif()
endforeach()

foreach(required
        vcpkg sdl2 boost lz4 zlib yaml-cpp sqlite bullet recastnavigation mygui
        freetype libpng libjpeg-turbo lua icu openal-soft ffmpeg gl4es osg)
    if(NOT required IN_LIST names)
        message(FATAL_ERROR "Required iOS dependency is not locked: ${required}")
    endif()
endforeach()

list(LENGTH names unique_dependency_count)
message(STATUS
    "Validated ${unique_dependency_count} pinned iOS dependencies "
    "(deployment ${deployment_target}, ${artifact_format})")
