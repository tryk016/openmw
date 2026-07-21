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
const cmake = process.env.CMAKE_COMMAND || "cmake";
const bash = process.env.BASH_COMMAND || "bash";
let closureFixturesSkipped = false;
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
