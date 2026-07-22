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
const hostToolsScript = fs.readFileSync(
    path.join(__dirname, "validate-host-tools.sh"),
    "utf8",
);
const prefixValidator = fs.readFileSync(
    path.join(__dirname, "validate-prefix.sh"),
    "utf8",
);
const smokeCmake = fs.readFileSync(
    path.join(repoRoot, "ios-deps/smoke/CMakeLists.txt"),
    "utf8",
);
const myGuiProbe = fs.readFileSync(
    path.join(repoRoot, "ios-deps/smoke/MyGUIProbe.cpp"),
    "utf8",
);
const myGuiOverlayRoot = path.join(
    repoRoot,
    "ios-deps/overlay-ports/mygui",
);
const myGuiPortfile = fs.readFileSync(
    path.join(myGuiOverlayRoot, "portfile.cmake"),
    "utf8",
);
const myGuiVersionPrintPatch = fs.readFileSync(
    path.join(myGuiOverlayRoot, "numeric-version-print.patch"),
    "utf8",
);
const myGuiOverlayManifest = JSON.parse(
    fs.readFileSync(path.join(myGuiOverlayRoot, "vcpkg.json"), "utf8"),
);
const dependenciesWorkflow = fs.readFileSync(
    path.join(repoRoot, ".github/workflows/ios-deps-ci.yml"),
    "utf8",
);
const smokeMain = fs.readFileSync(
    path.join(repoRoot, "ios-deps/smoke/Main.mm"),
    "utf8",
);
const simulatorSmokeScript = fs.readFileSync(
    path.join(repoRoot, "CI/ios/smoke-simulator.sh"),
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

function workflowJob(workflow, jobName) {
    const lines = workflow.split(/\r?\n/);
    const firstLine = lines.findIndex((line) => line === `  ${jobName}:`);
    if (firstLine === -1)
        return "";

    const nextJob = lines.findIndex(
        (line, index) =>
            index > firstLine && /^  [A-Za-z0-9_-]+:$/.test(line),
    );
    return lines
        .slice(firstLine + 1, nextJob === -1 ? lines.length : nextJob)
        .join("\n");
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
    const uiFoundationBuildJob = workflowJob(
        dependenciesWorkflow,
        "ui-foundation",
    );
    const uiFoundationRuntimeJob = workflowJob(
        dependenciesWorkflow,
        "ui-foundation-runtime",
    );
    requireBuildScriptContract(
        "ui-build-matrix-only-produces-evidence",
        uiFoundationBuildJob.includes("matrix:") &&
            uiFoundationBuildJob.includes(
                "name: ios-deps-ui-foundation-${{ matrix.platform }}-${{ github.sha }}",
            ) &&
            uiFoundationBuildJob.includes(
                "build/ios-deps/${{ matrix.platform }}/smoke/**/OpenMWDepsSmoke.app",
            ) &&
            /name: Archive simulator runtime input[\s\S]*?if: matrix\.platform == 'iphonesimulator'[\s\S]*?tar -C[\s\S]*?OpenMWDepsSmoke\.app\.tar\.gz/.test(
                uiFoundationBuildJob,
            ) &&
            /name: Upload simulator runtime input[\s\S]*?if: matrix\.platform == 'iphonesimulator'[\s\S]*?name: ios-deps-ui-foundation-runtime-input-\$\{\{ github\.sha \}\}[\s\S]*?path: build\/ios-deps\/\$\{\{ matrix\.platform \}\}\/runtime-input\/OpenMWDepsSmoke\.app\.tar\.gz[\s\S]*?overwrite: true/.test(
                uiFoundationBuildJob,
            ) &&
            !uiFoundationBuildJob.includes("smoke-simulator.sh") &&
            !uiFoundationBuildJob.includes("simctl") &&
            !uiFoundationBuildJob.includes("runtime-smoke"),
        "the expensive UI matrix must build and upload each platform artifact without starting a simulator",
    );
    requireBuildScriptContract(
        "ui-runtime-job-consumes-exact-simulator-artifact",
        uiFoundationRuntimeJob.includes("needs: ui-foundation") &&
            uiFoundationRuntimeJob.includes("runs-on: macos-15") &&
            uiFoundationRuntimeJob.includes(
                "DEVELOPER_DIR: /Applications/Xcode_16.4.app/Contents/Developer",
            ) &&
            uiFoundationRuntimeJob.includes(
                'test "$(xcodebuild -version | sed -n \'1p\')" = "Xcode 16.4"',
            ) &&
            /uses: actions\/download-artifact@v\d+/.test(
                uiFoundationRuntimeJob,
            ) &&
            uiFoundationRuntimeJob.includes(
                "name: ios-deps-ui-foundation-runtime-input-${{ github.sha }}",
            ) &&
            !uiFoundationRuntimeJob.includes(
                "ios-deps-ui-foundation-iphonesimulator",
            ) &&
            !uiFoundationRuntimeJob.includes("pattern:") &&
            !uiFoundationRuntimeJob.includes("merge-multiple:") &&
            uiFoundationRuntimeJob.includes(
                '-type f -name OpenMWDepsSmoke.app.tar.gz -print >"$archives_file"',
            ) &&
            uiFoundationRuntimeJob.includes(
                'if [[ "$archive_count" -ne 1 ]]; then',
            ) &&
            uiFoundationRuntimeJob.includes(
                'tar -xzf "$archive" -C "$extracted_root"',
            ) &&
            uiFoundationRuntimeJob.includes(
                '-type d -name OpenMWDepsSmoke.app -print >"$apps_file"',
            ) &&
            uiFoundationRuntimeJob.includes(
                'if [[ "$app_count" -ne 1 ]]; then',
            ) &&
            uiFoundationRuntimeJob.includes(
                'test "$bundle_id" = "org.openmw.ios.deps-smoke"',
            ) &&
            uiFoundationRuntimeJob.includes('test -n "$executable_name"') &&
            uiFoundationRuntimeJob.includes(
                'test -x "${app}/${executable_name}"',
            ) &&
            uiFoundationRuntimeJob.includes(
                "bash CI/ios/smoke-simulator.sh",
            ) &&
            uiFoundationRuntimeJob.includes(
                '"org.openmw.ios.deps-smoke"',
            ) &&
            uiFoundationRuntimeJob.includes('"ui foundation PASS"') &&
            uiFoundationRuntimeJob.includes(
                "name: ios-deps-ui-foundation-runtime-${{ github.sha }}-${{ github.run_attempt }}",
            ) &&
            !uiFoundationRuntimeJob.includes("CI/ios/deps/build.sh"),
        "the short runtime job must wait for the full matrix, download only the SHA-pinned tar input, restore and validate one executable app under Xcode 16.4, and execute the UI probe",
    );

    const runtimeResultNames = [
        "yamlResult",
        "sqliteResult",
        "bulletResult",
        "recastResult",
        "luaResult",
        "icuResult",
        "myGuiResult",
    ];
    const runtimeLogFields = [
        "sdlInitResult",
        "videoDriverCount",
        "lz4CompressedSize",
        "lz4RestoredSize",
        "lz4RoundTripPassed",
        "freeTypeInitResult",
        "pngPassed",
        "jpegPassed",
        "turboJpegPassed",
        "imageFoundationPassed",
        "yamlResult",
        "yamlPassed",
        "sqliteResult",
        "sqlitePassed",
        "bulletResult",
        "bulletPassed",
        "recastResult",
        "recastPassed",
        "luaResult",
        "luaPassed",
        "icuResult",
        "icuPassed",
        "myGuiResult",
        "myGuiPassed",
        "smokePassed",
    ];
    requireBuildScriptContract(
        "ui-runtime-log-is-complete",
        runtimeResultNames.every((resultName) =>
            new RegExp(`const int ${resultName}\\s*=`).test(smokeMain),
        ) &&
            /const bool jpegPassed\s*=\s*jpegDecoder\.mem != nullptr/.test(
                smokeMain,
            ) &&
            /imageFoundationPassed\s*=\s*freeTypeInitResult == 0 && pngPassed\s*&& jpegPassed && turboJpegPassed/.test(
                smokeMain,
            ) &&
            /const int myGuiResult\s*=\s*openmwIosMyGuiProbe\(\)/.test(
                smokeMain,
            ) &&
            runtimeLogFields.every((field) =>
                smokeMain.includes(`${field}=%{public}d`),
            ),
        "the unified log must expose every probe result and pass/fail boolean, including the raw MyGUI result",
    );

    const unifiedLogCapture = simulatorSmokeScript.indexOf(
        'xcrun simctl spawn "$udid" log show',
    );
    const screenshotCapture = simulatorSmokeScript.indexOf(
        'xcrun simctl io "$udid" screenshot',
    );
    const markerEvaluation = simulatorSmokeScript.indexOf(
        'grep -Fq "$expected_marker"',
    );
    const installBlock = simulatorSmokeScript.match(
        /if ! xcrun simctl install[\s\S]*?\nfi/,
    )?.[0];
    const launchBlock = simulatorSmokeScript.match(
        /if ! xcrun simctl launch[\s\S]*?\nfi/,
    )?.[0];
    requireBuildScriptContract(
        "simulator-diagnostics-are-fail-closed",
        unifiedLogCapture !== -1 &&
            screenshotCapture !== -1 &&
            markerEvaluation !== -1 &&
            unifiedLogCapture < markerEvaluation &&
            screenshotCapture < markerEvaluation &&
            installBlock !== undefined &&
            launchBlock !== undefined &&
            !installBlock.includes("exit 1") &&
            !launchBlock.includes("exit 1") &&
            installBlock.includes('runtime_failures+=("install")') &&
            launchBlock.includes('runtime_failures+=("launch")') &&
            simulatorSmokeScript.includes(
                'runtime_failures+=("unified-log")',
            ) &&
            simulatorSmokeScript.includes(
                'runtime_failures+=("screenshot")',
            ) &&
            /if \[\[ "\$\{#runtime_failures\[@\]\}" -ne 0 \]\]; then[\s\S]*exit 1\s*\nfi/.test(
                simulatorSmokeScript,
            ),
        "install and launch failures must survive through unconditional log/screenshot collection, marker evaluation, and a final non-zero exit",
    );

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
        "language-and-ui-host-tools-are-validated",
        /validate-host-tools\.sh/.test(buildScript) &&
            /profile="\$1"/.test(hostToolsScript) &&
            /case "\$profile" in\s*language-foundation\|ui-foundation\) ;;\s*\*\) exit 0 ;;\s*esac/.test(
                hostToolsScript,
            ) &&
            /icuinfo/.test(hostToolsScript) &&
            /icucross\.mk/.test(hostToolsScript) &&
            /port_version == 1/.test(hostToolsScript) &&
            /echo "Validated ICU 70\.1#1 host tools and target\/host separation"/.test(
                hostToolsScript,
            ),
        "the language and UI profiles must validate pinned ICU host tools and report success",
    );
    requireBuildScriptContract(
        "stdout-is-reserved-for-prefix",
        /exec 3>&1/.test(buildScript) &&
            /exec 1>&2/.test(buildScript) &&
            /printf '%s\\n' "\$prefix" >&3/.test(buildScript),
        "build.sh stdout must contain only the prefix consumed by GitHub Actions",
    );
    requireBuildScriptContract(
        "mygui-archive-retains-freetype-edge",
        /nm -u "\$\{prefix\}\/lib\/libMyGUIEngineStatic\.a"/.test(
            prefixValidator,
        ) &&
            /_FT_Init_FreeType/.test(prefixValidator) &&
            /_FT_Done_FreeType/.test(prefixValidator),
        "the MyGUI archive must retain explicit unresolved FreeType symbols",
    );
    const myGuiMetadataAllowlist = prefixValidator.match(
        /mygui_metadata_allowlist=\(\s*([^)]*?)\s*\)/,
    )?.[1].trim().split(/\s+/);
    requireBuildScriptContract(
        "mygui-prefix-metadata-allowlist-is-exact",
        JSON.stringify(myGuiMetadataAllowlist) ===
            JSON.stringify([
                "copyright",
                "vcpkg.spdx.json",
                "vcpkg_abi_info.txt",
            ]) &&
            /find "\$mygui_metadata_root" -mindepth 1 -print0/.test(
                prefixValidator,
            ) &&
            /"\$mygui_metadata_name" != \*\/\*/.test(prefixValidator) &&
            /-f "\$mygui_metadata_path"/.test(prefixValidator) &&
            /! -L "\$mygui_metadata_path"/.test(prefixValidator) &&
            /"\$\{mygui_metadata_allowlist\[@\]\}"/.test(prefixValidator) &&
            /if \[\[ "\$mygui_metadata_allowed" != true \]\]; then\s+forbidden_mygui_artifact="\$mygui_metadata_path"/.test(
                prefixValidator,
            ),
        "share/MYGUI must contain only regular, non-symlink vcpkg metadata files from the exact allowlist",
    );
    requireBuildScriptContract(
        "mygui-probe-executes-freetype-lifecycle",
        /FT_Init_FreeType\(&freeType\)/.test(myGuiProbe) &&
            /FT_Done_FreeType\(freeType\)/.test(myGuiProbe),
        "the renderer-free MyGUI probe must initialize and release FreeType",
    );
    const myGuiLockEntry = lock.dependencies.find(
        (dependency) => dependency.name === "mygui",
    );
    requireBuildScriptContract(
        "mygui-version-print-fix-is-explicit-and-locked",
        /PATCHES\s+llvm-char-types\.patch\s+ios-engine-only\.patch\s+numeric-version-print\.patch/.test(
            myGuiPortfile,
        ) &&
            (myGuiVersionPrintPatch.match(
                /^\+.*static_cast<unsigned int>\(mMajor\)/gm,
            )?.length ?? 0) === 2 &&
            (myGuiVersionPrintPatch.match(
                /^\+.*static_cast<unsigned int>\(mMinor\)/gm,
            )?.length ?? 0) === 2 &&
            !/^\+.*utility::toString\(mMajor/gm.test(
                myGuiVersionPrintPatch,
            ) &&
            myGuiOverlayManifest["port-version"] === 6 &&
            myGuiLockEntry?.vcpkg_port_source === "overlay" &&
            myGuiLockEntry?.vcpkg_port_version === 6,
        "the overlay must apply the numeric uint8_t stream fix after the existing patches and lock MyGUI 3.4.3#6",
    );
    requireBuildScriptContract(
        "mygui-probe-detects-version-print-regressions",
        /version\.print\(\) != "3\.4\.3"/.test(myGuiProbe) &&
            /widget->addAttribute\("engine", version\.print\(\)\)/.test(
                myGuiProbe,
            ) &&
            /document\.save\(encoded\)/.test(myGuiProbe) &&
            /decoded\.open\(input\)/.test(myGuiProbe) &&
            /children->findAttribute\("engine"\) != "3\.4\.3"/.test(
                myGuiProbe,
            ) &&
            !/versionText|std::to_string/.test(myGuiProbe),
        "the MyGUI probe must exercise Version::print through the XML round-trip without a silent local formatting workaround",
    );
    requireBuildScriptContract(
        "mygui-static-interface-is-transitive",
        /INTERFACE_LINK_LIBRARIES\s+"Freetype::Freetype;PNG::PNG;ZLIB::ZLIB"/.test(
            smokeCmake,
        ) &&
            /target_link_libraries\(openmw-ios-mygui-probe PRIVATE OpenMWIOS::MyGUI\)/.test(
                smokeCmake,
            ),
        "the MyGUI target must carry its full static closure for consumers",
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

    for (const profile of ["language-foundation", "ui-foundation"]) {
        const missingRequiredProfileLock = clone(lock);
        const missingRequiredProfileManifest = clone(manifest);
        delete missingRequiredProfileLock.build_profiles[profile];
        delete missingRequiredProfileLock.expected_vcpkg_transitive_ports[
            profile
        ];
        delete missingRequiredProfileManifest.features[profile];
        runValidator(
            `missing-required-${profile}`,
            missingRequiredProfileLock,
            missingRequiredProfileManifest,
            false,
        );
    }

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

    const missingLanguageLua = clone(manifest);
    missingLanguageLua.features["language-foundation"].dependencies =
        missingLanguageLua.features[
            "language-foundation"
        ].dependencies.filter((dependency) => dependency.name !== "lua");
    runValidator(
        "missing-language-lua",
        lock,
        missingLanguageLua,
        false,
    );

    const luaToolsLeak = clone(manifest);
    luaToolsLeak.features["language-foundation"].dependencies.find(
        (dependency) => dependency.name === "lua",
    ).features = ["tools"];
    runValidator("language-lua-tools-leak", lock, luaToolsLeak, false);

    const icuTargetToolsLeak = clone(manifest);
    icuTargetToolsLeak.features["language-foundation"].dependencies.find(
        (dependency) => dependency.name === "icu",
    ).features = ["tools"];
    runValidator(
        "language-icu-target-tools-leak",
        lock,
        icuTargetToolsLeak,
        false,
    );

    const changedIcuFilterHash = clone(lock);
    changedIcuFilterHash.dependencies.find(
        (dependency) => dependency.name === "icu",
    ).data_filter.sha256 = "0".repeat(64);
    runValidator(
        "changed-icu-filter-hash",
        changedIcuFilterHash,
        manifest,
        false,
    );

    const missingIcuHostTools = clone(lock);
    missingIcuHostTools.expected_vcpkg_transitive_ports[
        "language-foundation"
    ].host.find((entry) => entry.port === "icu").features = [];
    runValidator(
        "missing-icu-host-tools-feature",
        missingIcuHostTools,
        manifest,
        false,
    );
    const languageTriplet = "arm64-ios-openmw";
    const languageHostTriplet = "arm64-osx";
    const languageClosureRecords = [
        ...directPortEntries(lock, "language-foundation", languageTriplet),
        ...lock.expected_vcpkg_transitive_ports[
            "language-foundation"
        ].target.map((entry) =>
            installedRecord(
                entry.port,
                languageTriplet,
                entry.features ?? [],
            ),
        ),
        ...lock.expected_vcpkg_transitive_ports[
            "language-foundation"
        ].host.map((entry) =>
            installedRecord(
                entry.port,
                languageHostTriplet,
                entry.features ?? [],
            ),
        ),
    ];
    runClosureValidator(
        "valid-language-installed-closure",
        lock,
        languageClosureRecords,
        true,
        "language-foundation",
    );

    const languageClosureWithoutIcuTools = clone(languageClosureRecords);
    languageClosureWithoutIcuTools.find(
        (record) =>
            record.package_name === "icu" &&
            record.triplet === languageHostTriplet,
    ).features = [];
    runClosureValidator(
        "missing-installed-icu-host-tools",
        lock,
        languageClosureWithoutIcuTools,
        false,
        "language-foundation",
    );

    const missingUiMyGui = clone(manifest);
    missingUiMyGui.features["ui-foundation"].dependencies =
        missingUiMyGui.features["ui-foundation"].dependencies.filter(
            (dependency) => dependency.name !== "mygui",
        );
    runValidator("missing-ui-mygui", lock, missingUiMyGui, false);

    const myGuiFeatureLeak = clone(manifest);
    myGuiFeatureLeak.features["ui-foundation"].dependencies.find(
        (dependency) => dependency.name === "mygui",
    ).features = ["platform-opengl"];
    runValidator("ui-mygui-feature-leak", lock, myGuiFeatureLeak, false);

    const myGuiDefaultsEnabled = clone(manifest);
    myGuiDefaultsEnabled.features["ui-foundation"].dependencies.find(
        (dependency) => dependency.name === "mygui",
    )["default-features"] = true;
    runValidator(
        "ui-mygui-default-features-enabled",
        lock,
        myGuiDefaultsEnabled,
        false,
    );

    const missingMyGuiSourceHash = clone(lock);
    delete missingMyGuiSourceHash.dependencies.find(
        (dependency) => dependency.name === "mygui",
    ).vcpkg_sha512;
    runValidator(
        "missing-mygui-vcpkg-source-hash",
        missingMyGuiSourceHash,
        manifest,
        false,
    );

    const missingUiIcuHostTools = clone(lock);
    missingUiIcuHostTools.expected_vcpkg_transitive_ports[
        "ui-foundation"
    ].host.find((entry) => entry.port === "icu").features = [];
    runValidator(
        "missing-ui-icu-host-tools-feature",
        missingUiIcuHostTools,
        manifest,
        false,
    );

    const uiTriplet = "arm64-ios-openmw";
    const uiHostTriplet = "arm64-osx";
    const uiClosureRecords = [
        ...directPortEntries(lock, "ui-foundation", uiTriplet),
        ...lock.expected_vcpkg_transitive_ports[
            "ui-foundation"
        ].target.map((entry) =>
            installedRecord(entry.port, uiTriplet, entry.features ?? []),
        ),
        ...lock.expected_vcpkg_transitive_ports[
            "ui-foundation"
        ].host.map((entry) =>
            installedRecord(entry.port, uiHostTriplet, entry.features ?? []),
        ),
    ];
    runClosureValidator(
        "valid-ui-installed-closure",
        lock,
        uiClosureRecords,
        true,
        "ui-foundation",
    );

    const uiClosureWithoutIcuTools = clone(uiClosureRecords);
    uiClosureWithoutIcuTools.find(
        (record) =>
            record.package_name === "icu" &&
            record.triplet === uiHostTriplet,
    ).features = [];
    runClosureValidator(
        "missing-ui-installed-icu-host-tools",
        lock,
        uiClosureWithoutIcuTools,
        false,
        "ui-foundation",
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
