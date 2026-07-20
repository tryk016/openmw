#!/usr/bin/env node

const childProcess = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const repoRoot = path.resolve(__dirname, "../../..");
const validator = path.join(__dirname, "validate-lock.cmake");
const lock = JSON.parse(
    fs.readFileSync(path.join(repoRoot, "ios-deps/dependencies.lock.json"), "utf8"),
);
const manifest = JSON.parse(
    fs.readFileSync(path.join(repoRoot, "ios-deps/vcpkg.json"), "utf8"),
);
const cmake = process.env.CMAKE_COMMAND || "cmake";
const temporaryRoot = fs.mkdtempSync(
    path.join(os.tmpdir(), "openmw-ios-lock-contract-"),
);

function clone(value) {
    return structuredClone(value);
}

function runValidator(testName, testLock, testManifest, shouldPass) {
    const lockPath = path.join(temporaryRoot, `${testName}.lock.json`);
    const manifestPath = path.join(temporaryRoot, `${testName}.manifest.json`);
    fs.writeFileSync(lockPath, `${JSON.stringify(testLock, null, 2)}\n`);
    fs.writeFileSync(manifestPath, `${JSON.stringify(testManifest, null, 2)}\n`);

    const result = childProcess.spawnSync(
        cmake,
        [
            `-DLOCK_FILE=${lockPath}`,
            `-DMANIFEST_FILE=${manifestPath}`,
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

try {
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
} finally {
    fs.rmSync(temporaryRoot, { recursive: true, force: true });
}
