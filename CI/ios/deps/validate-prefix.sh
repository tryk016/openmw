#!/usr/bin/env bash
set -euo pipefail

if (($# != 2)); then
    echo "Usage: validate-prefix.sh iphoneos|iphonesimulator PREFIX" >&2
    exit 2
fi

platform="$1"
prefix="$2"
case "$platform" in
    iphoneos)
        expected_platform=IOS
        ;;
    iphonesimulator)
        expected_platform=IOSSIMULATOR
        ;;
    *)
        echo "Unsupported platform: $platform" >&2
        exit 2
        ;;
esac

if [[ ! -d "$prefix" ]]; then
    echo "Prefix does not exist: $prefix" >&2
    exit 1
fi

for command in ar file find lipo nm xcrun; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "Required command is unavailable: $command" >&2
        exit 1
    fi
done

if find "$prefix" \( -name '*.dylib' -o -name '*.framework' \) -print -quit |
        grep -q .; then
    echo "Static prefix contains a dynamic library or framework:" >&2
    find "$prefix" \( -name '*.dylib' -o -name '*.framework' \) -print >&2
    exit 1
fi

archives=()
while IFS= read -r archive; do
    archives+=("$archive")
done < <(find "$prefix" -type f -name '*.a' -print | sort)

if ((${#archives[@]} == 0)); then
    echo "No static archives found in prefix: $prefix" >&2
    exit 1
fi

if [[ -d "${prefix}/share/libjpeg-turbo" ]]; then
    for jpeg_archive in \
            "${prefix}/lib/libjpeg.a" \
            "${prefix}/lib/libturbojpeg.a"; do
        if [[ ! -f "$jpeg_archive" ]]; then
            echo "libjpeg-turbo package is missing: $jpeg_archive" >&2
            exit 1
        fi
        jpeg_members="$(ar -t "$jpeg_archive")"
        if ! grep -Eq '(^|/)jsimd\.c\.o$' <<<"$jpeg_members"; then
            echo "$jpeg_archive: arm64 SIMD dispatcher is missing" >&2
            exit 1
        fi
        if ! grep -Eq '(^|/)[A-Za-z0-9_-]+-neon\.c\.o$' \
                <<<"$jpeg_members"; then
            echo "$jpeg_archive: NEON implementation objects are missing" >&2
            exit 1
        fi
    done
fi

if [[ -d "${prefix}/share/boost" ]]; then
    for boost_archive in \
            libboost_atomic.a \
            libboost_chrono.a \
            libboost_container.a \
            libboost_date_time.a \
            libboost_graph.a \
            libboost_iostreams.a \
            libboost_program_options.a \
            libboost_random.a \
            libboost_serialization.a \
            libboost_thread.a \
            libboost_wserialization.a; do
        if [[ ! -f "${prefix}/lib/${boost_archive}" ]]; then
            echo "Boost package is missing: ${prefix}/lib/${boost_archive}" >&2
            exit 1
        fi
    done
fi

if [[ -d "${prefix}/share/bullet" ]]; then
    for bullet_path in \
            "${prefix}/lib/libBulletCollision.a" \
            "${prefix}/lib/libLinearMath.a" \
            "${prefix}/include/bullet/BulletCollision/CollisionShapes/btBvhTriangleMeshShape.h" \
            "${prefix}/include/bullet/LinearMath/btConvexHullComputer.h" \
            "${prefix}/share/bullet/BulletConfig.cmake" \
            "${prefix}/share/bullet3/copyright"; do
        if [[ ! -f "$bullet_path" ]]; then
            echo "Minimal Bullet package is missing: $bullet_path" >&2
            exit 1
        fi
    done

    unexpected_bullet_archive="$(
        find "${prefix}/lib" -maxdepth 1 -type f \
            \( -name 'libBulletDynamics*.a' \
            -o -name 'libBulletSoftBody*.a' \
            -o -name 'libBullet3*.a' \
            -o -name 'libBulletInverseDynamics*.a' \) \
            -print -quit
    )"
    if [[ -n "$unexpected_bullet_archive" ]]; then
        echo "Unexpected Bullet archive: $unexpected_bullet_archive" >&2
        exit 1
    fi

    for bullet_tool_root in \
            "${prefix}/tools" \
            "${prefix}/bin" \
            "${prefix}/share/bullet3"; do
        [[ -d "$bullet_tool_root" ]] || continue
        bullet_tool="$(
            find "$bullet_tool_root" -type f \
                \( -iname '*bullet*' -o -iname '*demo*' -o -iname '*test*' \) \
                -print -quit
        )"
        if [[ -n "$bullet_tool" ]]; then
            echo "Bullet tool/demo/test leaked into the target prefix: ${bullet_tool}" >&2
            exit 1
        fi
    done
fi

if [[ -d "${prefix}/share/recastnavigation" ]]; then
    for recast_path in \
            "${prefix}/lib/libRecast.a" \
            "${prefix}/lib/libDetour.a" \
            "${prefix}/lib/libDetourTileCache.a" \
            "${prefix}/lib/libDebugUtils.a" \
            "${prefix}/include/recastnavigation/Recast.h" \
            "${prefix}/include/recastnavigation/DetourNavMesh.h" \
            "${prefix}/include/recastnavigation/DetourNavMeshBuilder.h" \
            "${prefix}/include/recastnavigation/DetourNavMeshQuery.h" \
            "${prefix}/include/recastnavigation/DetourTileCache.h" \
            "${prefix}/include/recastnavigation/DebugDraw.h" \
            "${prefix}/include/recastnavigation/DetourDebugDraw.h" \
            "${prefix}/include/recastnavigation/version.h" \
            "${prefix}/share/recastnavigation/recastnavigation-config.cmake" \
            "${prefix}/share/recastnavigation/recastnavigation-config-version.cmake" \
            "${prefix}/share/recastnavigation/recastnavigation-targets.cmake" \
            "${prefix}/share/recastnavigation/recastnavigation-targets-release.cmake" \
            "${prefix}/share/recastnavigation/copyright"; do
        if [[ ! -f "$recast_path" ]]; then
            echo "Minimal RecastNavigation package is missing: $recast_path" >&2
            exit 1
        fi
    done

    unexpected_recast_archive="$(
        find "${prefix}/lib" -maxdepth 1 -type f \
            \( -iname '*recast*.a' -o -iname '*detour*.a' \
            -o -iname '*debugutils*.a' \) \
            ! -name 'libRecast.a' \
            ! -name 'libDetour.a' \
            ! -name 'libDetourTileCache.a' \
            ! -name 'libDebugUtils.a' \
            -print -quit
    )"
    if [[ -n "$unexpected_recast_archive" ]]; then
        echo "Unexpected RecastNavigation archive: $unexpected_recast_archive" >&2
        exit 1
    fi

    forbidden_recast_package_path="$(
        find "${prefix}/include/recastnavigation" \
            "${prefix}/share/recastnavigation" \
            -type f \
            \( -iname '*crowd*' -o -iname '*demo*' \
            -o -iname '*example*' -o -iname '*test*' \) \
            -print -quit
    )"
    if [[ -n "$forbidden_recast_package_path" ]]; then
        echo "Crowd/demo/test leaked into RecastNavigation: $forbidden_recast_package_path" >&2
        exit 1
    fi

    forbidden_recast_tool="$(
        find "${prefix}/tools" "${prefix}/bin" -type f \
            \( -iname '*recast*' -o -iname '*detour*' \
            -o -iname '*debugutils*' \) \
            -print -quit 2>/dev/null || true
    )"
    if [[ -n "$forbidden_recast_tool" ]]; then
        echo "RecastNavigation tool leaked into target prefix: $forbidden_recast_tool" >&2
        exit 1
    fi
fi

if [[ -d "${prefix}/share/yaml-cpp" ]]; then
    for yaml_path in \
            "${prefix}/lib/libyaml-cpp.a" \
            "${prefix}/include/yaml-cpp/yaml.h"; do
        if [[ ! -f "$yaml_path" ]]; then
            echo "yaml-cpp package is missing: $yaml_path" >&2
            exit 1
        fi
    done
fi

if [[ -d "${prefix}/share/sqlite3" \
        || -d "${prefix}/share/unofficial-sqlite3" ]]; then
    for sqlite_path in \
            "${prefix}/lib/libsqlite3.a" \
            "${prefix}/include/sqlite3.h" \
            "${prefix}/include/sqlite3-vcpkg-config.h"; do
        if [[ ! -f "$sqlite_path" ]]; then
            echo "SQLite package is missing: $sqlite_path" >&2
            exit 1
        fi
    done
    if ! grep -Eq \
            '^[[:space:]]*#define[[:space:]]+SQLITE_OMIT_LOAD_EXTENSION([[:space:]]+1)?[[:space:]]*$' \
            "${prefix}/include/sqlite3-vcpkg-config.h"; then
        echo "SQLite extension loading was not omitted" >&2
        exit 1
    fi
    if grep -Eq \
            '^[[:space:]]*#define[[:space:]]+SQLITE_OMIT_JSON([[:space:]]+1)?[[:space:]]*$' \
            "${prefix}/include/sqlite3-vcpkg-config.h"; then
        echo "SQLite JSON support was unexpectedly omitted" >&2
        exit 1
    fi
    for sqlite_tool_root in "${prefix}/tools" "${prefix}/bin"; do
        [[ -d "$sqlite_tool_root" ]] || continue
        sqlite_tool="$(
            find "$sqlite_tool_root" -type f \
                \( -name sqlite3 -o -name 'sqlite3*' \) \
                -print -quit
        )"
        if [[ -n "$sqlite_tool" ]]; then
            echo "SQLite command-line tool leaked into the target prefix: ${sqlite_tool}" >&2
            exit 1
        fi
    done
fi

if [[ -d "${prefix}/share/unofficial-lua" ]]; then
    for lua_path in \
            "${prefix}/lib/liblua.a" \
            "${prefix}/include/lua.h" \
            "${prefix}/include/lua.hpp" \
            "${prefix}/include/lauxlib.h" \
            "${prefix}/include/lualib.h" \
            "${prefix}/share/lua/copyright" \
            "${prefix}/share/unofficial-lua/unofficial-lua-config.cmake"; do
        if [[ ! -f "$lua_path" ]]; then
            echo "The minimal Lua package is missing: $lua_path" >&2
            exit 1
        fi
    done
    if ! grep -Eq \
            '^[[:space:]]*#define[[:space:]]+LUA_VERSION_NUM[[:space:]]+501[[:space:]]*$' \
            "${prefix}/include/lua.h"; then
        echo "The target prefix does not contain PUC Lua 5.1" >&2
        exit 1
    fi
    if find "${prefix}" -type f \
            \( -path '*/bin/lua' -o -path '*/bin/luac' \
            -o -path '*/tools/lua/*' \) -print -quit | grep -q .; then
        echo "A Lua interpreter/compiler leaked into the target prefix" >&2
        exit 1
    fi
fi

if [[ -d "${prefix}/share/icu" ]]; then
    for icu_path in \
            "${prefix}/lib/libicudata.a" \
            "${prefix}/lib/libicuuc.a" \
            "${prefix}/lib/libicui18n.a" \
            "${prefix}/include/unicode/uversion.h" \
            "${prefix}/share/icu/copyright"; do
        if [[ ! -f "$icu_path" ]]; then
            echo "The minimal ICU package is missing: $icu_path" >&2
            exit 1
        fi
    done
    unexpected_icu_archive="$(
        find "${prefix}/lib" -maxdepth 1 -type f -name 'libicu*.a' \
            ! -name libicudata.a \
            ! -name libicuuc.a \
            ! -name libicui18n.a \
            -print -quit
    )"
    if [[ -n "$unexpected_icu_archive" ]]; then
        echo "Unexpected ICU target archive: $unexpected_icu_archive" >&2
        exit 1
    fi
    if find "${prefix}" -type f \
            \( -path '*/tools/icu/*' -o -path '*/bin/icu*' \
            -o -path '*/bin/gen*' -o -path '*/sbin/*' \) \
            -print -quit | grep -q .; then
        echo "An ICU host tool leaked into the target prefix" >&2
        exit 1
    fi
fi

if [[ -d "${prefix}/share/mygui" \
        || -f "${prefix}/lib/libMyGUIEngineStatic.a" ]]; then
    for mygui_path in \
            "${prefix}/lib/libMyGUIEngineStatic.a" \
            "${prefix}/lib/pkgconfig/MYGUIStatic.pc" \
            "${prefix}/include/MYGUI/MyGUI.h" \
            "${prefix}/include/MYGUI/MyGUI_Prerequest.h" \
            "${prefix}/include/MYGUI/MyGUI_UString.h" \
            "${prefix}/include/MYGUI/MyGUI_XmlDocument.h" \
            "${prefix}/share/mygui/copyright"; do
        if [[ ! -f "$mygui_path" ]]; then
            echo "The static MyGUI engine package is missing: $mygui_path" >&2
            exit 1
        fi
    done

    unexpected_mygui_archive="$(
        find "${prefix}/lib" -maxdepth 1 -type f -iname '*mygui*.a' \
            ! -name libMyGUIEngineStatic.a -print -quit
    )"
    if [[ -n "$unexpected_mygui_archive" ]]; then
        echo "Unexpected MyGUI archive: $unexpected_mygui_archive" >&2
        exit 1
    fi

    mygui_undefined_symbols="$(
        nm -u "${prefix}/lib/libMyGUIEngineStatic.a"
    )"
    for freetype_symbol in _FT_Init_FreeType _FT_Done_FreeType; do
        if ! grep -Eq "(^|[[:space:]])${freetype_symbol}([[:space:]]|$)" \
                <<<"$mygui_undefined_symbols"; then
            echo "MyGUI engine does not expose the expected FreeType dependency: ${freetype_symbol}" >&2
            exit 1
        fi
    done

    if ! grep -Eq '^[[:space:]]*#define[[:space:]]+MYGUI_VERSION_MAJOR[[:space:]]+3[[:space:]]*$' \
            "${prefix}/include/MYGUI/MyGUI_Prerequest.h" ||
            ! grep -Eq '^[[:space:]]*#define[[:space:]]+MYGUI_VERSION_MINOR[[:space:]]+4[[:space:]]*$' \
            "${prefix}/include/MYGUI/MyGUI_Prerequest.h" ||
            ! grep -Eq '^[[:space:]]*#define[[:space:]]+MYGUI_VERSION_PATCH[[:space:]]+3[[:space:]]*$' \
            "${prefix}/include/MYGUI/MyGUI_Prerequest.h"; then
        echo "The target prefix does not contain MyGUI 3.4.3 headers" >&2
        exit 1
    fi
    if ! grep -Eq 'using[[:space:]]+unicode_char[[:space:]]*=[[:space:]]*char32_t;' \
            "${prefix}/include/MYGUI/MyGUI_UString.h" ||
            ! grep -Eq 'using[[:space:]]+code_point[[:space:]]*=[[:space:]]*char16_t;' \
            "${prefix}/include/MYGUI/MyGUI_UString.h"; then
        echo "The MyGUI LLVM char16_t/char32_t ABI patch is missing" >&2
        exit 1
    fi
    if ! grep -Eq \
            'Cflags:.*-DMYGUI_STATIC.*-DMYGUI_USE_FREETYPE.*-DMYGUI_DONT_USE_OBSOLETE' \
            "${prefix}/lib/pkgconfig/MYGUIStatic.pc"; then
        echo "MyGUI consumer ABI definitions are incomplete" >&2
        exit 1
    fi

    forbidden_mygui_artifact=""
    for mygui_forbidden_root in \
            "${prefix}/bin" \
            "${prefix}/tools" \
            "${prefix}/lib/MYGUI"; do
        [[ -e "$mygui_forbidden_root" || -L "$mygui_forbidden_root" ]] || continue
        if [[ ! -d "$mygui_forbidden_root" || -L "$mygui_forbidden_root" ]]; then
            forbidden_mygui_artifact="$mygui_forbidden_root"
        else
            forbidden_mygui_artifact="$(
                find "$mygui_forbidden_root" -mindepth 1 -print -quit
            )"
        fi
        [[ -z "$forbidden_mygui_artifact" ]] || break
    done
    if [[ -n "$forbidden_mygui_artifact" ]]; then
        echo "MyGUI platform/plugin/tool/demo artifact leaked into the prefix: $forbidden_mygui_artifact" >&2
        exit 1
    fi

    mygui_metadata_allowlist=(
        copyright
        vcpkg.spdx.json
        vcpkg_abi_info.txt
    )
    mygui_metadata_root="${prefix}/share/MYGUI"
    if [[ -e "$mygui_metadata_root" || -L "$mygui_metadata_root" ]]; then
        if [[ ! -d "$mygui_metadata_root" || -L "$mygui_metadata_root" ]]; then
            forbidden_mygui_artifact="$mygui_metadata_root"
        else
            while IFS= read -r -d '' mygui_metadata_path; do
                mygui_metadata_name="${mygui_metadata_path#"${mygui_metadata_root}/"}"
                mygui_metadata_allowed=false
                if [[ "$mygui_metadata_name" != */* \
                        && -f "$mygui_metadata_path" \
                        && ! -L "$mygui_metadata_path" ]]; then
                    for allowed_mygui_metadata in \
                            "${mygui_metadata_allowlist[@]}"; do
                        if [[ "$mygui_metadata_name" == "$allowed_mygui_metadata" ]]; then
                            mygui_metadata_allowed=true
                            break
                        fi
                    done
                fi
                if [[ "$mygui_metadata_allowed" != true ]]; then
                    forbidden_mygui_artifact="$mygui_metadata_path"
                    break
                fi
            done < <(find "$mygui_metadata_root" -mindepth 1 -print0)
        fi
        if [[ -n "$forbidden_mygui_artifact" ]]; then
            echo "Unexpected MyGUI runtime/plugin/tool entry in metadata directory: $forbidden_mygui_artifact" >&2
            exit 1
        fi
    fi
fi

temporary_root="$(mktemp -d)"
trap 'rm -rf "$temporary_root"' EXIT
object_count=0

for archive in "${archives[@]}"; do
    archive_archs="$(lipo -archs "$archive")"
    if [[ "$archive_archs" != arm64 ]]; then
        echo "${archive}: expected only arm64, got '${archive_archs}'" >&2
        exit 1
    fi

    archive_name="$(basename "$archive" .a)"
    extract_dir="${temporary_root}/${archive_name}-${object_count}"
    mkdir -p "$extract_dir"
    (
        cd "$extract_dir"
        ar -x "$archive"
    )

    objects=()
    while IFS= read -r object; do
        objects+=("$object")
    done < <(
        find "$extract_dir" -type f ! -name '__.SYMDEF*' -print | sort
    )
    if ((${#objects[@]} == 0)); then
        echo "${archive}: archive is empty" >&2
        exit 1
    fi

    for object in "${objects[@]}"; do
        if ! file "$object" | grep -q 'Mach-O 64-bit.*arm64'; then
            echo "${archive}: non-arm64 Mach-O member: $(file "$object")" >&2
            exit 1
        fi
        build_info="$(xcrun vtool -show-build "$object")"
        if ! grep -Eq "platform[[:space:]]+${expected_platform}$" \
                <<<"$build_info"; then
            echo "${archive}: member has the wrong build platform" >&2
            echo "$build_info" >&2
            exit 1
        fi
        if ! grep -Eq 'minos[[:space:]]+16\.4([[:space:]]|$)' \
                <<<"$build_info"; then
            echo "${archive}: member does not declare min iOS 16.4" >&2
            echo "$build_info" >&2
            exit 1
        fi
        ((object_count += 1))
    done
done

echo "Validated ${#archives[@]} static archives and ${object_count} Mach-O members"
echo "platform=${expected_platform}, architecture=arm64, minos=16.4"
