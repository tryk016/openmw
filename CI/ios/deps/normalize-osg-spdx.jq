def require($condition; $message):
    if $condition then . else error($message) end;

"LicenseRef-OSGPL-1.0" as $license_id
| {
    licenseId: $license_id,
    name: "OpenSceneGraph Public License, Version 1.0",
    extractedText: $extractedText
} as $licensing_info
| require(
    (($extractedText | type) == "string" and ($extractedText | length) > 0);
    "osg: installed copyright is empty"
)
| require((.packages | type) == "array"; "osg: SPDX packages must be an array")
| (.packages | map(select(.name? == "osg"))) as $source_packages
| (
    .packages
    | map(
        select(
            ((.name? | type) == "string")
                and (.name | startswith("osg:"))
        )
    )
) as $binary_packages
| require(
    ($source_packages | length) == 1
        and $source_packages[0].description
            == "Minimal static OpenMW OpenSceneGraph fork for iOS";
    "osg: unexpected SPDX source package identity"
)
| require(
    ($binary_packages | length) == 1
        and (
            $binary_packages[0].name == "osg:arm64-ios-openmw"
                or $binary_packages[0].name
                    == "osg:arm64-ios-simulator-openmw"
        );
    "osg: unexpected SPDX binary package identity"
)
| require(
    $source_packages[0].licenseConcluded == $license_id
        and ($binary_packages | all(.licenseConcluded == $license_id));
    "osg: expected LicenseRef-OSGPL-1.0 on source and binary packages"
)
| (
    if has("hasExtractedLicensingInfos") then
        require(
            (.hasExtractedLicensingInfos | type) == "array";
            "osg: hasExtractedLicensingInfos must be an array"
        )
        | .hasExtractedLicensingInfos
    else
        []
    end
) as $existing_infos
| (
    $existing_infos
    | map(select(.licenseId? == $license_id))
) as $osg_infos
| require(
    ($osg_infos | length) <= 1;
    "osg: duplicate LicenseRef-OSGPL-1.0 extracted licensing information"
)
| require(
    ($osg_infos | length) == 0 or $osg_infos[0] == $licensing_info;
    "osg: conflicting LicenseRef-OSGPL-1.0 extracted licensing information"
)
| if ($osg_infos | length) == 0 then
    .hasExtractedLicensingInfos = ($existing_infos + [$licensing_info])
else
    .
end
