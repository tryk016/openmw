#!/usr/bin/env node

const childProcess = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const repoRoot = path.resolve(__dirname, "../../..");
const validator = path.join(__dirname, "validate-lock.cmake");
const closureValidator = path.join(__dirname, "validate-installed-closure.sh");
const lock = JSON.parse(
    fs.readFileSync(path.join(repoRoot, "ios-deps/dependencies.lock.json"), "utf8"),
);
const manifest = JSON.parse(
    fs.readFileSync(path.join(repoRoot, "ios-deps/vcpkg.json"), "utf8"),
);
const configuration = JSON.parse(
    fs.readFileSync(
        path.join(repoRoot, "ios-deps/vcpkg-configuration.json"),
        "utf8",
    ),
);
const buildScript = fs.readFileSync(
    path.join(__dirname, "build.sh"),
    "utf8",
);
const bootstrapScript = fs.readFileSync(
    path.join(__dirname, "bootstrap-vcpkg.sh"),
    "utf8",
);
const packageMetadataScript = fs.readFileSync(
    path.join(__dirname, "package-metadata.sh"),
    "utf8",
);
const boostUninstallSpdxValidator = path.join(
    __dirname,
    "validate-boost-uninstall-spdx.jq",
);
const cmake = process.env.CMAKE_COMMAND || "cmake";
const bash = process.env.BASH_COMMAND || "bash";
const jq = process.env.JQ_COMMAND || "jq";
let closureFixturesSkipped = false;
let spdxFixturesSkipped = false;
const temporaryRoot = fs.mkdtempSync(
    path.join(os.tmpdir(), "openmw-ios-lock-contract-"),
);

function clone(value) {
    return structuredClone(value);
}

function runValidator(
    testName,
    testLock,
    testManifest,
    shouldPass,
    testConfiguration = configuration,
) {
    const lockPath = path.join(temporaryRoot, `${testName}.lock.json`);
    const manifestPath = path.join(temporaryRoot, `${testName}.manifest.json`);
    const configurationPath = path.join(
        temporaryRoot,
        `${testName}.configuration.json`,
    );
    fs.writeFileSync(lockPath, `${JSON.stringify(testLock, null, 2)}\n`);
    fs.writeFileSync(manifestPath, `${JSON.stringify(testManifest, null, 2)}\n`);
    fs.writeFileSync(
        configurationPath,
        `${JSON.stringify(testConfiguration, null, 2)}\n`,
    );

    const result = childProcess.spawnSync(
        cmake,
        [
            `-DLOCK_FILE=${lockPath}`,
            `-DMANIFEST_FILE=${manifestPath}`,
            `-DCONFIGURATION_FILE=${configurationPath}`,
            "-P",
            validator,
        ],
        { encoding: "utf8" },
    );
    if (result.error)
        throw result.error;
    const passed = result.status === 0;
    if (passed !== shouldPass) {
        process.stderr.write(result.stdout);
        process.stderr.write(result.stderr);
        throw new Error(
            `${testName}: expected validator to ${shouldPass ? "pass" : "reject"}`,
        );
    }
    process.stdout.write(
        `${testName}: ${shouldPass ? "accepted" : "rejected"} as expected\n`,
    );
}

function installedRecord(
    packageName,
    triplet,
    features = [],
    version = "1.0.0",
    portVersion = 0,
) {
    return {
        package_name: packageName,
        triplet,
        version,
        port_version: portVersion,
        features,
    };
}

function directPortEntries(testLock, profile, targetTriplet) {
    const dependencies = new Map(
        testLock.dependencies.map((dependency) => [dependency.name, dependency]),
    );
    return testLock.build_profiles[profile].map((dependencyName) => {
        const dependency = dependencies.get(dependencyName);
        return installedRecord(
            dependency.vcpkg_port,
            targetTriplet,
            dependency.vcpkg_features,
            dependency.version,
            dependency.vcpkg_port_version ?? 0,
        );
    });
}

function installedJson(records) {
    return Object.fromEntries(
        records.map((record, index) => [
            `${record.package_name}:${record.triplet}:${index}`,
            record,
        ]),
    );
}

function runClosureValidator(
    testName,
    testLock,
    records,
    shouldPass,
    profile = "image-foundation",
) {
    if (closureFixturesSkipped)
        return;

    const lockPath = path.join(temporaryRoot, `${testName}.closure.lock.json`);
    const installedPath = path.join(
        temporaryRoot,
        `${testName}.installed.json`,
    );
    fs.writeFileSync(lockPath, `${JSON.stringify(testLock, null, 2)}\n`);
    fs.writeFileSync(
        installedPath,
        `${JSON.stringify(installedJson(records), null, 2)}\n`,
    );

    const result = childProcess.spawnSync(
        bash,
        [
            closureValidator,
            "--lock",
            lockPath,
            "--installed-json",
            installedPath,
            "--profile",
            profile,
            "--target-triplet",
            "arm64-ios-openmw",
            "--host-triplet",
            "arm64-osx",
        ],
        { encoding: "utf8" },
    );
    if (result.error?.code === "ENOENT") {
        if (!closureFixturesSkipped) {
            process.stdout.write(
                `installed-closure fixtures skipped: '${bash}' is unavailable; Ubuntu CI must execute them\n`,
            );
            closureFixturesSkipped = true;
        }
        return;
    }
    if (result.error)
        throw result.error;
    const passed = result.status === 0;
    if (passed !== shouldPass) {
        process.stderr.write(result.stdout);
        process.stderr.write(result.stderr);
        throw new Error(
            `${testName}: expected closure validator to ${shouldPass ? "pass" : "reject"}`,
        );
    }
    process.stdout.write(
        `${testName}: closure ${shouldPass ? "accepted" : "rejected"} as expected\n`,
    );
}

function requireBuildScriptContract(testName, predicate, message) {
    if (!predicate)
        throw new Error(`${testName}: ${message}`);
    process.stdout.write(`${testName}: build script contract accepted\n`);
}

function runBoostUninstallSpdxValidator(
    testName,
    document,
    shouldPass,
) {
    if (spdxFixturesSkipped)
        return;

    const result = childProcess.spawnSync(
        jq,
        ["-e", "-f", boostUninstallSpdxValidator],
        {
            encoding: "utf8",
            input: `${JSON.stringify(document)}\n`,
        },
    );
    if (result.error?.code === "ENOENT") {
        process.stdout.write(
            `boost-uninstall SPDX fixtures skipped: '${jq}' is unavailable; Ubuntu CI must execute them\n`,
        );
        spdxFixturesSkipped = true;
        return;
    }
    if (result.error)
        throw result.error;
    const passed = result.status === 0;
    if (passed !== shouldPass) {
        process.stderr.write(result.stdout);
        process.stderr.write(result.stderr);
        throw new Error(
            `${testName}: expected SPDX validator to ${shouldPass ? "pass" : "reject"}`,
        );
    }
    process.stdout.write(
        `${testName}: SPDX ${shouldPass ? "accepted" : "rejected"} as expected\n`,
    );
}

try {
    requireBuildScriptContract(
        "offline-downloads-are-fresh",
        /downloads="\$\{platform_root\}\/offline-downloads"/.test(buildScript) &&
            /rm -rf "\$downloads"/.test(buildScript),
        "offline builds must reset a profile-local downloads directory",
    );
    requireBuildScriptContract(
        "offline-assets-block-origin",
        /X_VCPKG_ASSET_SOURCES="clear;x-azurl,file:\/\/\$\{asset_cache\},,read;x-block-origin"/.test(
            buildScript,
        ),
        "offline builds must use the asset cache read-only and block origin",
    );
    requireBuildScriptContract(
        "offline-does-not-bypass-assets",
        !/^\s*vcpkg_args\+=\([^\n]*--no-downloads/m.test(buildScript),
        "--no-downloads would bypass the content-addressed asset cache",
    );
    requireBuildScriptContract(
        "vcpkg-registry-history-is-complete",
        /git -C "\$vcpkg_root" fetch --no-tags origin "\$revision"/.test(
            bootstrapScript,
        ) &&
            !/\bgit\b[^\n]*\b(?:--depth|--shallow)/.test(bootstrapScript) &&
            /rev-parse --is-shallow-repository/.test(bootstrapScript),
        "the builtin registry needs complete Git history and a shallow-check guard",
    );
    requireBuildScriptContract(
        "overlay-port-selection-is-explicit",
        /overlay_ports="\$\{manifest_root\}\/overlay-ports"/.test(buildScript) &&
            /case "\$vcpkg_port_source" in[\s\S]*builtin\)[\s\S]*vcpkg_root[\s\S]*overlay\)[\s\S]*overlay_ports/.test(
                buildScript,
            ) &&
            /overlay_vcpkg_args\+=\("--overlay-ports=\$\{overlay_port_dir\}"\)/.test(
                buildScript,
            ) &&
            /vcpkg_args\+=\("\$\{overlay_vcpkg_args\[@\]\}"\)/.test(
                buildScript,
            ) &&
            !/--overlay-ports="\$overlay_ports"/.test(buildScript),
        "only overlay ports selected by the active lock profile may reach vcpkg",
    );
    requireBuildScriptContract(
        "boost-uninstall-notice-is-narrow",
        /IOS_DEPS_BUILD_ROOT/.test(packageMetadataScript) &&
            /IOS_DEPS_VCPKG_ROOT/.test(packageMetadataScript) &&
            /boost_uninstall_spdx_validator=.*validate-boost-uninstall-spdx\.jq/.test(
                packageMetadataScript,
            ) &&
            /case "\$package" in[\s\S]*boost-uninstall\)[\s\S]*jq -e -f "\$boost_uninstall_spdx_validator"/.test(
                packageMetadataScript,
            ) &&
            /git -C "\$vcpkg_root" show/.test(packageMetadataScript) &&
            /cmp - "\$vcpkg_license"/.test(packageMetadataScript),
        "only the identified MIT boost-uninstall helper may use the pinned vcpkg notice",
    );

    const validBoostUninstallSpdx = {
        packages: [
            {
                name: "boost-uninstall",
                description: "Internal vcpkg port used to uninstall Boost",
                licenseConcluded: "MIT",
            },
            {
                name: "boost-uninstall:arm64-ios-openmw",
                licenseConcluded: "MIT",
            },
        ],
    };
    runBoostUninstallSpdxValidator(
        "valid-boost-uninstall-spdx",
        validBoostUninstallSpdx,
        true,
    );

    const wrongBoostUninstallLicense = clone(validBoostUninstallSpdx);
    wrongBoostUninstallLicense.packages[0].licenseConcluded = "NOASSERTION";
    runBoostUninstallSpdxValidator(
        "wrong-boost-uninstall-license",
        wrongBoostUninstallLicense,
        false,
    );

    const duplicateBoostUninstallPort = clone(validBoostUninstallSpdx);
    duplicateBoostUninstallPort.packages.push(
        clone(duplicateBoostUninstallPort.packages[0]),
    );
    runBoostUninstallSpdxValidator(
        "duplicate-boost-uninstall-port",
        duplicateBoostUninstallPort,
        false,
    );

    const missingBoostUninstallBinary = clone(validBoostUninstallSpdx);
    missingBoostUninstallBinary.packages.pop();
    runBoostUninstallSpdxValidator(
        "missing-boost-uninstall-binary",
        missingBoostUninstallBinary,
        false,
    );

    const unrelatedMissingNotice = clone(validBoostUninstallSpdx);
    unrelatedMissingNotice.packages[0].name = "boost-uninstall-extra";
    runBoostUninstallSpdxValidator(
        "unrelated-missing-notice",
        unrelatedMissingNotice,
        false,
    );

    const reorderedManifest = clone(manifest);
    reorderedManifest.features["image-foundation"].dependencies.reverse();
    const reorderedFreetype = reorderedManifest.features[
        "image-foundation"
    ].dependencies.find((dependency) => dependency.name === "freetype");
    reorderedFreetype.features.reverse();
    runValidator("valid-reordering", lock, reorderedManifest, true);

    const missingPng = clone(manifest);
    missingPng.features["image-foundation"].dependencies.find(
        (dependency) => dependency.name === "freetype",
    ).features = ["zlib"];
    runValidator("missing-freetype-png", lock, missingPng, false);

    const extraBrotli = clone(manifest);
    extraBrotli.features["image-foundation"].dependencies.find(
        (dependency) => dependency.name === "freetype",
    ).features.push("brotli");
    runValidator("unexpected-freetype-brotli", lock, extraBrotli, false);

    const enabledDefaults = clone(manifest);
    enabledDefaults.features["image-foundation"].dependencies.find(
        (dependency) => dependency.name === "freetype",
    )["default-features"] = true;
    runValidator("enabled-default-features", lock, enabledDefaults, false);

    const extraDirectPort = clone(manifest);
    extraDirectPort.features["image-foundation"].dependencies.push({
        name: "boost-program-options",
        "default-features": false,
    });
    runValidator("unexpected-direct-port", lock, extraDirectPort, false);

    const duplicateFeature = clone(manifest);
    duplicateFeature.features["image-foundation"].dependencies.find(
        (dependency) => dependency.name === "freetype",
    ).features.push("png");
    runValidator("duplicate-feature", lock, duplicateFeature, false);

    const missingSqliteRestriction = clone(manifest);
    missingSqliteRestriction.features["data-foundation"].dependencies.find(
        (dependency) => dependency.name === "sqlite3",
    ).features = ["json1"];
    runValidator(
        "missing-sqlite-omit-load-extension",
        lock,
        missingSqliteRestriction,
        false,
    );

    const sqliteToolLeak = clone(manifest);
    sqliteToolLeak.features["data-foundation"].dependencies.find(
        (dependency) => dependency.name === "sqlite3",
    ).features.push("tool");
    runValidator("unexpected-sqlite-tool", lock, sqliteToolLeak, false);

    const dataDefaultsEnabled = clone(manifest);
    dataDefaultsEnabled.features["data-foundation"].dependencies.find(
        (dependency) => dependency.name === "yaml-cpp",
    )["default-features"] = true;
    runValidator(
        "data-default-features-enabled",
        lock,
        dataDefaultsEnabled,
        false,
    );

    const malformedUrlMarker = clone(lock);
    malformedUrlMarker.dependencies.find(
        (dependency) => dependency.name === "sqlite",
    ).vcpkg_source_marker =
        "URLS \"http://sqlite.org/sqlite-autoconf-${SQLITE_VERSION}.tar.gz\"";
    runValidator(
        "non-https-source-marker",
        malformedUrlMarker,
        manifest,
        false,
    );

    const missingBulletMultithreading = clone(manifest);
    missingBulletMultithreading.features[
        "physics-foundation"
    ].dependencies.find(
        (dependency) => dependency.name === "bullet3",
    ).features = ["double-precision"];
    runValidator(
        "missing-bullet-multithreading",
        lock,
        missingBulletMultithreading,
        false,
    );

    const unexpectedBulletDynamics = clone(manifest);
    unexpectedBulletDynamics.features[
        "physics-foundation"
    ].dependencies.find(
        (dependency) => dependency.name === "bullet3",
    ).features.push("dynamics");
    runValidator(
        "unexpected-bullet-dynamics",
        lock,
        unexpectedBulletDynamics,
        false,
    );

    const bulletDefaultsEnabled = clone(manifest);
    bulletDefaultsEnabled.features[
        "physics-foundation"
    ].dependencies.find(
        (dependency) => dependency.name === "bullet3",
    )["default-features"] = true;
    runValidator(
        "bullet-default-features-enabled",
        lock,
        bulletDefaultsEnabled,
        false,
    );

    const missingRecast = clone(manifest);
    missingRecast.features["navigation-foundation"].dependencies =
        missingRecast.features["navigation-foundation"].dependencies.filter(
            (dependency) => dependency.name !== "recastnavigation",
        );
    runValidator("missing-navigation-recast", lock, missingRecast, false);

    const unexpectedRecastFeature = clone(manifest);
    unexpectedRecastFeature.features[
        "navigation-foundation"
    ].dependencies.find(
        (dependency) => dependency.name === "recastnavigation",
    ).features = ["crowd"];
    runValidator(
        "unexpected-recast-crowd-feature",
        lock,
        unexpectedRecastFeature,
        false,
    );

    const recastDefaultsEnabled = clone(manifest);
    recastDefaultsEnabled.features[
        "navigation-foundation"
    ].dependencies.find(
        (dependency) => dependency.name === "recastnavigation",
    )["default-features"] = true;
    runValidator(
        "recast-default-features-enabled",
        lock,
        recastDefaultsEnabled,
        false,
    );

    const missingRecastSourceHash = clone(lock);
    delete missingRecastSourceHash.dependencies.find(
        (dependency) => dependency.name === "recastnavigation",
    ).vcpkg_sha512;
    runValidator(
        "missing-recast-vcpkg-source-hash",
        missingRecastSourceHash,
        manifest,
        false,
    );

    const missingPortSource = clone(lock);
    delete missingPortSource.dependencies.find(
        (dependency) => dependency.name === "bullet",
    ).vcpkg_port_source;
    runValidator(
        "missing-vcpkg-port-source",
        missingPortSource,
        manifest,
        false,
    );

    const invalidPortSource = clone(lock);
    invalidPortSource.dependencies.find(
        (dependency) => dependency.name === "bullet",
    ).vcpkg_port_source = "registry-fallback";
    runValidator(
        "invalid-vcpkg-port-source",
        invalidPortSource,
        manifest,
        false,
    );

    const closureLock = clone(lock);
    closureLock.expected_vcpkg_transitive_ports ??= {};
    closureLock.expected_vcpkg_transitive_ports["image-foundation"] = {
        target: [
            { port: "fixture-target" },
            { port: "fixture-featured", features: ["fast"] },
        ],
        host: [{ port: "fixture-host" }],
    };
    runValidator("valid-transitive-closure", closureLock, manifest, true);

    const unknownClosureProfile = clone(closureLock);
    unknownClosureProfile.expected_vcpkg_transitive_ports.unknown = {
        target: [],
        host: [],
    };
    runValidator(
        "unknown-closure-profile",
        unknownClosureProfile,
        manifest,
        false,
    );

    const missingHostClosure = clone(closureLock);
    delete missingHostClosure.expected_vcpkg_transitive_ports[
        "image-foundation"
    ].host;
    runValidator("missing-host-closure", missingHostClosure, manifest, false);

    const duplicateClosurePort = clone(closureLock);
    duplicateClosurePort.expected_vcpkg_transitive_ports[
        "image-foundation"
    ].target.push({ port: "fixture-target" });
    runValidator(
        "duplicate-closure-port",
        duplicateClosurePort,
        manifest,
        false,
    );

    const repeatedDirectPort = clone(closureLock);
    const directDependencyName =
        repeatedDirectPort.build_profiles["image-foundation"][0];
    const directPort = repeatedDirectPort.dependencies.find(
        (dependency) => dependency.name === directDependencyName,
    ).vcpkg_port;
    repeatedDirectPort.expected_vcpkg_transitive_ports[
        "image-foundation"
    ].target.push({ port: directPort });
    runValidator("direct-port-as-transitive", repeatedDirectPort, manifest, false);

    const duplicateClosureFeature = clone(closureLock);
    duplicateClosureFeature.expected_vcpkg_transitive_ports[
        "image-foundation"
    ].target[1].features.push("fast");
    runValidator(
        "duplicate-closure-feature",
        duplicateClosureFeature,
        manifest,
        false,
    );

    const invalidPortVersion = clone(lock);
    invalidPortVersion.dependencies.find(
        (dependency) => dependency.name === "freetype",
    ).vcpkg_port_version = -1;
    runValidator("negative-port-version", invalidPortVersion, manifest, false);

    const stringPortVersion = clone(lock);
    stringPortVersion.dependencies.find(
        (dependency) => dependency.name === "freetype",
    ).vcpkg_port_version = "1";
    runValidator("string-port-version", stringPortVersion, manifest, false);

    const mismatchedConfiguration = clone(configuration);
    mismatchedConfiguration["default-registry"].baseline = "0".repeat(40);
    runValidator(
        "registry-baseline-mismatch",
        lock,
        manifest,
        false,
        mismatchedConfiguration,
    );

    const targetTriplet = "arm64-ios-openmw";
    const hostTriplet = "arm64-osx";
    const closureRecords = [
        ...directPortEntries(closureLock, "image-foundation", targetTriplet),
        installedRecord("fixture-target", targetTriplet),
        installedRecord("fixture-featured", targetTriplet, ["fast"]),
        installedRecord("fixture-host", hostTriplet),
    ];
    runClosureValidator(
        "valid-installed-closure",
        closureLock,
        closureRecords,
        true,
    );

    runClosureValidator(
        "missing-target-transitive",
        closureLock,
        closureRecords.filter(
            (record) => record.package_name !== "fixture-target",
        ),
        false,
    );

    runClosureValidator(
        "extra-target-port",
        closureLock,
        [...closureRecords, installedRecord("fixture-extra", targetTriplet)],
        false,
    );

    const missingFeatureRecords = clone(closureRecords);
    missingFeatureRecords.find(
        (record) => record.package_name === "fixture-featured",
    ).features = [];
    runClosureValidator(
        "missing-installed-feature",
        closureLock,
        missingFeatureRecords,
        false,
    );

    const extraFeatureRecords = clone(closureRecords);
    extraFeatureRecords.find(
        (record) => record.package_name === "fixture-featured",
    ).features.push("unexpected");
    runClosureValidator(
        "extra-installed-feature",
        closureLock,
        extraFeatureRecords,
        false,
    );

    const hostUnderTargetTriplet = clone(closureRecords);
    hostUnderTargetTriplet.find(
        (record) => record.package_name === "fixture-host",
    ).triplet = targetTriplet;
    runClosureValidator(
        "host-port-under-target-triplet",
        closureLock,
        hostUnderTargetTriplet,
        false,
    );

    runClosureValidator(
        "unexpected-installed-triplet",
        closureLock,
        [...closureRecords, installedRecord("fixture-third", "x64-linux")],
        false,
    );

    runClosureValidator(
        "duplicate-installed-tuple",
        closureLock,
        [...closureRecords, clone(closureRecords[0])],
        false,
    );

    const legacyLock = clone(lock);
    delete legacyLock.expected_vcpkg_transitive_ports?.["image-foundation"];
    runClosureValidator(
        "legacy-profile-ignores-host",
        legacyLock,
        [
            ...directPortEntries(legacyLock, "image-foundation", targetTriplet),
            installedRecord("legacy-host-tool", hostTriplet),
        ],
        true,
    );
} finally {
    fs.rmSync(temporaryRoot, { recursive: true, force: true });
}
