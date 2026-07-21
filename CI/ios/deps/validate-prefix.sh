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

for command in ar file find lipo xcrun; do
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
            "${prefix}/share/bullet/copyright"; do
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
