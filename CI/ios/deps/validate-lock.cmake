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

string(JSON profile_count ERROR_VARIABLE profile_error
    LENGTH "${lock}" build_profiles)
if(profile_error OR profile_count LESS 1)
    message(FATAL_ERROR
        "The dependency lock must define at least one build_profiles entry")
endif()

set(profile_names)
math(EXPR last_profile "${profile_count} - 1")
foreach(profile_index RANGE 0 ${last_profile})
    string(JSON profile_name MEMBER
        "${lock}" build_profiles ${profile_index})
    if(NOT profile_name MATCHES "^[a-z0-9][a-z0-9-]*$")
        message(FATAL_ERROR
            "Invalid dependency build profile name: ${profile_name}")
    endif()
    list(APPEND profile_names "${profile_name}")

    string(JSON profile_dependency_count LENGTH
        "${lock}" build_profiles "${profile_name}")
    if(profile_dependency_count LESS 1)
        message(FATAL_ERROR
            "Dependency build profile is empty: ${profile_name}")
    endif()

    set(profile_dependencies)
    math(EXPR last_profile_dependency "${profile_dependency_count} - 1")
    foreach(dependency_index RANGE 0 ${last_profile_dependency})
        string(JSON profile_dependency GET
            "${lock}" build_profiles "${profile_name}" ${dependency_index})
        if(NOT profile_dependency IN_LIST names)
            message(FATAL_ERROR
                "${profile_name}: unknown locked dependency "
                "'${profile_dependency}'")
        endif()
        if(profile_dependency STREQUAL "vcpkg")
            message(FATAL_ERROR
                "${profile_name}: vcpkg is tooling, not a target package")
        endif()
        if(profile_dependency IN_LIST profile_dependencies)
            message(FATAL_ERROR
                "${profile_name}: duplicate dependency "
                "'${profile_dependency}'")
        endif()
        list(APPEND profile_dependencies "${profile_dependency}")

        list(FIND names "${profile_dependency}" locked_dependency_index)
        foreach(field vcpkg_port vcpkg_sha512
                vcpkg_default_features vcpkg_features)
            string(JSON value ERROR_VARIABLE vcpkg_field_error
                GET "${lock}" dependencies ${locked_dependency_index} ${field})
            if(vcpkg_field_error)
                message(FATAL_ERROR
                    "${profile_name}/${profile_dependency}: active dependency "
                    "is missing '${field}'")
            endif()
        endforeach()

        string(JSON vcpkg_port GET
            "${lock}" dependencies ${locked_dependency_index} vcpkg_port)
        if(NOT vcpkg_port MATCHES "^[a-z0-9][a-z0-9-]*$")
            message(FATAL_ERROR
                "${profile_name}/${profile_dependency}: invalid vcpkg port "
                "'${vcpkg_port}'")
        endif()

        string(JSON vcpkg_sha512 GET
            "${lock}" dependencies ${locked_dependency_index} vcpkg_sha512)
        string(LENGTH "${vcpkg_sha512}" vcpkg_hash_length)
        if(NOT vcpkg_hash_length EQUAL 128 OR
                NOT vcpkg_sha512 MATCHES "^[0-9a-f]+$")
            message(FATAL_ERROR
                "${profile_name}/${profile_dependency}: vcpkg_sha512 must be "
                "128 lowercase hex digits")
        endif()

        string(JSON vcpkg_feature_count LENGTH
            "${lock}" dependencies ${locked_dependency_index} vcpkg_features)
        if(NOT vcpkg_feature_count EQUAL 0)
            message(FATAL_ERROR
                "${profile_name}/${profile_dependency}: non-empty vcpkg "
                "feature sets are not supported by lock schema 1")
        endif()
    endforeach()
endforeach()

set(manifest_file
    "${CMAKE_CURRENT_LIST_DIR}/../../../ios-deps/vcpkg.json")
file(READ "${manifest_file}" manifest)

foreach(profile_name IN LISTS profile_names)
    string(JSON manifest_dependency_count
        ERROR_VARIABLE manifest_feature_error
        LENGTH "${manifest}" features "${profile_name}" dependencies)
    if(manifest_feature_error OR manifest_dependency_count LESS 1)
        message(FATAL_ERROR
            "Lock build profile '${profile_name}' has no matching non-empty "
            "vcpkg manifest feature")
    endif()

    set(manifest_ports)
    set(manifest_default_features)
    math(EXPR last_manifest_dependency "${manifest_dependency_count} - 1")
    foreach(manifest_dependency_index RANGE 0 ${last_manifest_dependency})
        string(JSON manifest_dependency_type TYPE
            "${manifest}" features "${profile_name}" dependencies
            ${manifest_dependency_index})
        if(manifest_dependency_type STREQUAL "STRING")
            string(JSON manifest_port GET
                "${manifest}" features "${profile_name}" dependencies
                ${manifest_dependency_index})
            set(manifest_defaults ON)
        elseif(manifest_dependency_type STREQUAL "OBJECT")
            string(JSON manifest_port ERROR_VARIABLE manifest_port_error
                GET "${manifest}" features "${profile_name}" dependencies
                ${manifest_dependency_index} name)
            if(manifest_port_error)
                message(FATAL_ERROR
                    "${profile_name}: dependency object "
                    "${manifest_dependency_index} has no name")
            endif()
            string(JSON manifest_defaults ERROR_VARIABLE defaults_error
                GET "${manifest}" features "${profile_name}" dependencies
                ${manifest_dependency_index} default-features)
            if(defaults_error)
                set(manifest_defaults ON)
            endif()

            string(JSON manifest_feature_count ERROR_VARIABLE features_error
                LENGTH "${manifest}" features "${profile_name}" dependencies
                ${manifest_dependency_index} features)
            if(NOT features_error AND NOT manifest_feature_count EQUAL 0)
                message(FATAL_ERROR
                    "${profile_name}/${manifest_port}: non-empty vcpkg "
                    "feature sets are not supported by lock schema 1")
            endif()
        else()
            message(FATAL_ERROR
                "${profile_name}: dependency ${manifest_dependency_index} "
                "must be a string or object")
        endif()

        if(manifest_port IN_LIST manifest_ports)
            message(FATAL_ERROR
                "${profile_name}: duplicate manifest port '${manifest_port}'")
        endif()
        list(APPEND manifest_ports "${manifest_port}")
        list(APPEND manifest_default_features "${manifest_defaults}")
    endforeach()

    set(expected_ports)
    string(JSON profile_dependency_count LENGTH
        "${lock}" build_profiles "${profile_name}")
    math(EXPR last_profile_dependency "${profile_dependency_count} - 1")
    foreach(dependency_index RANGE 0 ${last_profile_dependency})
        string(JSON profile_dependency GET
            "${lock}" build_profiles "${profile_name}" ${dependency_index})
        list(FIND names "${profile_dependency}" locked_dependency_index)
        string(JSON expected_port GET
            "${lock}" dependencies ${locked_dependency_index} vcpkg_port)
        list(APPEND expected_ports "${expected_port}")

        list(FIND manifest_ports "${expected_port}" manifest_port_index)
        if(manifest_port_index EQUAL -1)
            message(FATAL_ERROR
                "${profile_name}: locked port '${expected_port}' is absent "
                "from the vcpkg manifest feature")
        endif()
        list(GET manifest_default_features ${manifest_port_index}
            actual_default_features)
        string(JSON expected_default_features GET
            "${lock}" dependencies ${locked_dependency_index}
            vcpkg_default_features)
        if(NOT actual_default_features STREQUAL expected_default_features)
            message(FATAL_ERROR
                "${profile_name}/${expected_port}: default-features mismatch "
                "(lock=${expected_default_features}, "
                "manifest=${actual_default_features})")
        endif()
    endforeach()

    list(SORT expected_ports)
    list(SORT manifest_ports)
    if(NOT expected_ports STREQUAL manifest_ports)
        message(FATAL_ERROR
            "${profile_name}: lock and vcpkg manifest dependencies differ "
            "(lock=${expected_ports}; manifest=${manifest_ports})")
    endif()
endforeach()

foreach(required_profile bootstrap base-foundation)
    if(NOT required_profile IN_LIST profile_names)
        message(FATAL_ERROR
            "Required dependency build profile is missing: "
            "${required_profile}")
    endif()
endforeach()

string(JSON manifest_profile_count LENGTH "${manifest}" features)
math(EXPR last_manifest_profile "${manifest_profile_count} - 1")
foreach(manifest_profile_index RANGE 0 ${last_manifest_profile})
    string(JSON manifest_profile_name MEMBER
        "${manifest}" features ${manifest_profile_index})
    if(NOT manifest_profile_name IN_LIST profile_names)
        message(FATAL_ERROR
            "vcpkg manifest feature '${manifest_profile_name}' has no "
            "matching lock build profile")
    endif()
endforeach()

list(LENGTH names unique_dependency_count)
message(STATUS
    "Validated ${unique_dependency_count} pinned iOS dependencies "
    "and ${profile_count} build profiles "
    "(deployment ${deployment_target}, ${artifact_format})")
