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

    if(name STREQUAL "icu")
        foreach(filter_field path canonical_line_endings sha256 sha512)
            string(JSON filter_value ERROR_VARIABLE filter_error
                GET "${lock}" dependencies ${index}
                data_filter ${filter_field})
            if(filter_error)
                message(FATAL_ERROR
                    "icu: data_filter is missing '${filter_field}'")
            endif()
        endforeach()

        string(JSON filter_path GET "${lock}" dependencies ${index}
            data_filter path)
        if(NOT filter_path STREQUAL "extern/icufilters.json")
            message(FATAL_ERROR
                "icu: data_filter.path must remain extern/icufilters.json")
        endif()
        string(JSON filter_line_endings GET "${lock}" dependencies ${index}
            data_filter canonical_line_endings)
        if(NOT filter_line_endings STREQUAL "LF")
            message(FATAL_ERROR
                "icu: data_filter canonical line endings must be LF")
        endif()

        set(filter_file "${CMAKE_CURRENT_LIST_DIR}/../../../${filter_path}")
        if(NOT EXISTS "${filter_file}")
            message(FATAL_ERROR "icu: data filter file is missing: ${filter_file}")
        endif()
        file(READ "${filter_file}" filter_contents)
        string(REPLACE "\r\n" "\n" filter_contents "${filter_contents}")
        string(SHA256 actual_filter_sha256 "${filter_contents}")
        string(SHA512 actual_filter_sha512 "${filter_contents}")
        string(JSON expected_filter_sha256 GET "${lock}" dependencies ${index}
            data_filter sha256)
        string(JSON expected_filter_sha512 GET "${lock}" dependencies ${index}
            data_filter sha512)
        if(NOT actual_filter_sha256 STREQUAL expected_filter_sha256 OR
                NOT actual_filter_sha512 STREQUAL expected_filter_sha512)
            message(FATAL_ERROR
                "icu: canonical LF data filter hash does not match the lock")
        endif()
    endif()
endforeach()

if(NOT DEFINED CONFIGURATION_FILE)
    set(CONFIGURATION_FILE
        "${CMAKE_CURRENT_LIST_DIR}/../../../ios-deps/vcpkg-configuration.json")
endif()
if(NOT EXISTS "${CONFIGURATION_FILE}")
    message(FATAL_ERROR
        "vcpkg configuration file does not exist: ${CONFIGURATION_FILE}")
endif()
file(READ "${CONFIGURATION_FILE}" vcpkg_configuration)
string(JSON registry_kind ERROR_VARIABLE registry_kind_error
    GET "${vcpkg_configuration}" default-registry kind)
string(JSON registry_baseline ERROR_VARIABLE registry_baseline_error
    GET "${vcpkg_configuration}" default-registry baseline)
if(registry_kind_error OR NOT registry_kind STREQUAL "builtin" OR
        registry_baseline_error)
    message(FATAL_ERROR
        "vcpkg configuration must define a pinned builtin default registry")
endif()
list(FIND names "vcpkg" vcpkg_dependency_index)
if(vcpkg_dependency_index EQUAL -1)
    message(FATAL_ERROR "Required iOS dependency is not locked: vcpkg")
endif()
string(JSON vcpkg_revision GET
    "${lock}" dependencies ${vcpkg_dependency_index} revision)
if(NOT registry_baseline STREQUAL vcpkg_revision)
    message(FATAL_ERROR
        "vcpkg registry baseline does not match the locked vcpkg revision "
        "(baseline=${registry_baseline}, lock=${vcpkg_revision})")
endif()

foreach(required
        vcpkg sdl2 boost-iostreams boost-program-options boost-geometry
        lz4 zlib yaml-cpp sqlite bullet recastnavigation mygui
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
        foreach(field vcpkg_port vcpkg_port_source vcpkg_source_marker
                vcpkg_sha512 vcpkg_default_features vcpkg_features)
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

        string(JSON vcpkg_port_source GET
            "${lock}" dependencies ${locked_dependency_index}
            vcpkg_port_source)
        if(NOT vcpkg_port_source STREQUAL "builtin"
                AND NOT vcpkg_port_source STREQUAL "overlay")
            message(FATAL_ERROR
                "${profile_name}/${profile_dependency}: "
                "vcpkg_port_source must be 'builtin' or 'overlay'")
        endif()

        string(JSON vcpkg_port_version ERROR_VARIABLE port_version_error
            GET "${lock}" dependencies ${locked_dependency_index}
            vcpkg_port_version)
        if(port_version_error)
            set(vcpkg_port_version 0)
        else()
            string(JSON vcpkg_port_version_type TYPE
                "${lock}" dependencies ${locked_dependency_index}
                vcpkg_port_version)
            if(NOT vcpkg_port_version_type STREQUAL "NUMBER" OR
                    NOT vcpkg_port_version MATCHES "^[0-9]+$")
                message(FATAL_ERROR
                    "${profile_name}/${profile_dependency}: "
                    "vcpkg_port_version must be a non-negative integer")
            endif()
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

        string(JSON vcpkg_source_marker GET
            "${lock}" dependencies ${locked_dependency_index}
            vcpkg_source_marker)
        if(NOT vcpkg_source_marker MATCHES
                    "^REPO [A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$"
                AND NOT vcpkg_source_marker MATCHES
                    "^URLS \"https://[^\" \t\r\n]+\"$")
            message(FATAL_ERROR
                "${profile_name}/${profile_dependency}: invalid "
                "vcpkg_source_marker '${vcpkg_source_marker}'; expected an "
                "exact REPO owner/name or quoted HTTPS URLS marker")
        endif()

        string(JSON vcpkg_feature_count LENGTH
            "${lock}" dependencies ${locked_dependency_index} vcpkg_features)
        set(locked_vcpkg_features)
        if(vcpkg_feature_count GREATER 0)
            math(EXPR last_vcpkg_feature "${vcpkg_feature_count} - 1")
            foreach(feature_index RANGE 0 ${last_vcpkg_feature})
                string(JSON locked_vcpkg_feature GET
                    "${lock}" dependencies ${locked_dependency_index}
                    vcpkg_features ${feature_index})
                if(NOT locked_vcpkg_feature
                        MATCHES "^[a-z0-9][a-z0-9-]*$" OR
                        locked_vcpkg_feature STREQUAL "core")
                    message(FATAL_ERROR
                        "${profile_name}/${profile_dependency}: invalid "
                        "vcpkg feature '${locked_vcpkg_feature}'")
                endif()
                if(locked_vcpkg_feature IN_LIST locked_vcpkg_features)
                    message(FATAL_ERROR
                        "${profile_name}/${profile_dependency}: duplicate "
                        "vcpkg feature '${locked_vcpkg_feature}'")
                endif()
                list(APPEND locked_vcpkg_features
                    "${locked_vcpkg_feature}")
            endforeach()
        endif()
    endforeach()
endforeach()

# Direct dependencies remain the human-authored manifest contract.  Profiles
# with a non-trivial resolver graph can additionally pin the exact target and
# host-only transitive port/feature closure without repeating direct ports.
string(JSON closure_type ERROR_VARIABLE closure_error
    TYPE "${lock}" expected_vcpkg_transitive_ports)
if(NOT closure_error)
    if(NOT closure_type STREQUAL "OBJECT")
        message(FATAL_ERROR
            "expected_vcpkg_transitive_ports must be an object")
    endif()

    string(JSON closure_profile_count LENGTH
        "${lock}" expected_vcpkg_transitive_ports)
    if(closure_profile_count GREATER 0)
        math(EXPR last_closure_profile "${closure_profile_count} - 1")
        foreach(closure_profile_index RANGE 0 ${last_closure_profile})
            string(JSON closure_profile MEMBER
                "${lock}" expected_vcpkg_transitive_ports
                ${closure_profile_index})
            if(NOT closure_profile IN_LIST profile_names)
                message(FATAL_ERROR
                    "Transitive closure references unknown profile "
                    "'${closure_profile}'")
            endif()

            string(JSON closure_profile_type TYPE
                "${lock}" expected_vcpkg_transitive_ports
                "${closure_profile}")
            if(NOT closure_profile_type STREQUAL "OBJECT")
                message(FATAL_ERROR
                    "${closure_profile}: transitive closure must be an object")
            endif()

            set(closure_direct_ports)
            set(icu_host_tools_found FALSE)
            string(JSON closure_direct_count LENGTH
                "${lock}" build_profiles "${closure_profile}")
            math(EXPR last_closure_direct "${closure_direct_count} - 1")
            foreach(closure_direct_index RANGE 0 ${last_closure_direct})
                string(JSON closure_direct_dependency GET
                    "${lock}" build_profiles "${closure_profile}"
                    ${closure_direct_index})
                list(FIND names "${closure_direct_dependency}"
                    closure_direct_dependency_index)
                string(JSON closure_direct_port GET
                    "${lock}" dependencies
                    ${closure_direct_dependency_index} vcpkg_port)
                list(APPEND closure_direct_ports "${closure_direct_port}")
            endforeach()

            foreach(closure_scope target host)
                string(JSON closure_scope_type ERROR_VARIABLE scope_error
                    TYPE "${lock}" expected_vcpkg_transitive_ports
                    "${closure_profile}" "${closure_scope}")
                if(scope_error OR NOT closure_scope_type STREQUAL "ARRAY")
                    message(FATAL_ERROR
                        "${closure_profile}: transitive closure '${closure_scope}' "
                        "must be an array")
                endif()

                string(JSON closure_entry_count LENGTH
                    "${lock}" expected_vcpkg_transitive_ports
                    "${closure_profile}" "${closure_scope}")
                set(closure_scope_ports)
                if(closure_entry_count GREATER 0)
                    math(EXPR last_closure_entry "${closure_entry_count} - 1")
                    foreach(closure_entry_index RANGE 0 ${last_closure_entry})
                        string(JSON closure_entry_type TYPE
                            "${lock}" expected_vcpkg_transitive_ports
                            "${closure_profile}" "${closure_scope}"
                            ${closure_entry_index})
                        if(NOT closure_entry_type STREQUAL "OBJECT")
                            message(FATAL_ERROR
                                "${closure_profile}/${closure_scope}: closure "
                                "entry ${closure_entry_index} must be an object")
                        endif()

                        string(JSON closure_port ERROR_VARIABLE closure_port_error
                            GET "${lock}" expected_vcpkg_transitive_ports
                            "${closure_profile}" "${closure_scope}"
                            ${closure_entry_index} port)
                        if(closure_port_error OR NOT closure_port
                                MATCHES "^[a-z0-9][a-z0-9-]*$")
                            message(FATAL_ERROR
                                "${closure_profile}/${closure_scope}: closure "
                                "entry ${closure_entry_index} has invalid port")
                        endif()
                        if(closure_port IN_LIST closure_scope_ports)
                            message(FATAL_ERROR
                                "${closure_profile}/${closure_scope}: duplicate "
                                "transitive port '${closure_port}'")
                        endif()
                        list(APPEND closure_scope_ports "${closure_port}")
                        if(closure_scope STREQUAL "target" AND
                                closure_port IN_LIST closure_direct_ports)
                            message(FATAL_ERROR
                                "${closure_profile}: direct port '${closure_port}' "
                                "must not be repeated as target transitive")
                        endif()

                        string(JSON closure_features_type
                            ERROR_VARIABLE closure_features_error TYPE
                            "${lock}" expected_vcpkg_transitive_ports
                            "${closure_profile}" "${closure_scope}"
                            ${closure_entry_index} features)
                        set(closure_features)
                        if(NOT closure_features_error)
                            if(NOT closure_features_type STREQUAL "ARRAY")
                                message(FATAL_ERROR
                                    "${closure_profile}/${closure_scope}/"
                                    "${closure_port}: features must be an array")
                            endif()
                            string(JSON closure_feature_count LENGTH
                                "${lock}" expected_vcpkg_transitive_ports
                                "${closure_profile}" "${closure_scope}"
                                ${closure_entry_index} features)
                            if(closure_feature_count GREATER 0)
                                math(EXPR last_closure_feature
                                    "${closure_feature_count} - 1")
                                foreach(closure_feature_index RANGE 0
                                        ${last_closure_feature})
                                    string(JSON closure_feature GET
                                        "${lock}"
                                        expected_vcpkg_transitive_ports
                                        "${closure_profile}" "${closure_scope}"
                                        ${closure_entry_index} features
                                        ${closure_feature_index})
                                    if(NOT closure_feature
                                            MATCHES "^[a-z0-9][a-z0-9-]*$" OR
                                            closure_feature STREQUAL "core")
                                        message(FATAL_ERROR
                                            "${closure_profile}/${closure_scope}/"
                                            "${closure_port}: invalid feature "
                                            "'${closure_feature}'")
                                    endif()
                                    if(closure_feature IN_LIST closure_features)
                                        message(FATAL_ERROR
                                            "${closure_profile}/${closure_scope}/"
                                            "${closure_port}: duplicate feature "
                                            "'${closure_feature}'")
                                    endif()
                                    list(APPEND closure_features
                                        "${closure_feature}")
                                endforeach()
                            endif()
                        endif()
                        if("icu" IN_LIST closure_direct_ports AND
                                closure_scope STREQUAL "host" AND
                                closure_port STREQUAL "icu")
                            if(NOT closure_features STREQUAL "tools")
                                message(FATAL_ERROR
                                    "${closure_profile}: host icu must enable "
                                    "exactly the tools feature")
                            endif()
                            set(icu_host_tools_found TRUE)
                        endif()
                    endforeach()
                endif()
            endforeach()
            if("icu" IN_LIST closure_direct_ports AND
                    NOT icu_host_tools_found)
                message(FATAL_ERROR
                    "${closure_profile}: host icu[tools] closure is required")
            endif()
        endforeach()
    endif()
endif()

if(NOT DEFINED MANIFEST_FILE)
    set(MANIFEST_FILE
        "${CMAKE_CURRENT_LIST_DIR}/../../../ios-deps/vcpkg.json")
endif()
if(NOT EXISTS "${MANIFEST_FILE}")
    message(FATAL_ERROR
        "Dependency manifest file does not exist: ${MANIFEST_FILE}")
endif()
file(READ "${MANIFEST_FILE}" manifest)

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
    set(manifest_feature_sets)
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
            set(manifest_feature_set "<none>")
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
            set(manifest_dependency_features)
            if(NOT features_error AND manifest_feature_count GREATER 0)
                math(EXPR last_manifest_feature
                    "${manifest_feature_count} - 1")
                foreach(feature_index RANGE 0 ${last_manifest_feature})
                    string(JSON manifest_dependency_feature GET
                        "${manifest}" features "${profile_name}" dependencies
                        ${manifest_dependency_index} features ${feature_index})
                    if(NOT manifest_dependency_feature
                            MATCHES "^[a-z0-9][a-z0-9-]*$" OR
                            manifest_dependency_feature STREQUAL "core")
                        message(FATAL_ERROR
                            "${profile_name}/${manifest_port}: invalid vcpkg "
                            "feature '${manifest_dependency_feature}'")
                    endif()
                    if(manifest_dependency_feature
                            IN_LIST manifest_dependency_features)
                        message(FATAL_ERROR
                            "${profile_name}/${manifest_port}: duplicate "
                            "vcpkg feature '${manifest_dependency_feature}'")
                    endif()
                    list(APPEND manifest_dependency_features
                        "${manifest_dependency_feature}")
                endforeach()
            endif()
            list(SORT manifest_dependency_features)
            if(manifest_dependency_features)
                string(JOIN "," manifest_feature_set
                    ${manifest_dependency_features})
            else()
                set(manifest_feature_set "<none>")
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
        list(APPEND manifest_feature_sets "${manifest_feature_set}")
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

        set(expected_dependency_features)
        string(JSON expected_feature_count LENGTH
            "${lock}" dependencies ${locked_dependency_index} vcpkg_features)
        if(expected_feature_count GREATER 0)
            math(EXPR last_expected_feature "${expected_feature_count} - 1")
            foreach(feature_index RANGE 0 ${last_expected_feature})
                string(JSON expected_dependency_feature GET
                    "${lock}" dependencies ${locked_dependency_index}
                    vcpkg_features ${feature_index})
                list(APPEND expected_dependency_features
                    "${expected_dependency_feature}")
            endforeach()
        endif()
        list(SORT expected_dependency_features)
        if(expected_dependency_features)
            string(JOIN "," expected_feature_set
                ${expected_dependency_features})
        else()
            set(expected_feature_set "<none>")
        endif()
        list(GET manifest_feature_sets ${manifest_port_index}
            actual_feature_set)
        if(NOT actual_feature_set STREQUAL expected_feature_set)
            message(FATAL_ERROR
                "${profile_name}/${expected_port}: vcpkg feature mismatch "
                "(lock=${expected_feature_set}, "
                "manifest=${actual_feature_set})")
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

foreach(required_profile
        bootstrap base-foundation image-foundation cpp-foundation
        data-foundation physics-foundation navigation-foundation
        language-foundation ui-foundation multimedia-foundation
        render-foundation)
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
