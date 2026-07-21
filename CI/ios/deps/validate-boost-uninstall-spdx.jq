[.packages[] | select(.name == "boost-uninstall")] as $ports
| [.packages[] | select(.name | startswith("boost-uninstall:"))] as $binaries
| ($ports | length) == 1
    and $ports[0].description
        == "Internal vcpkg port used to uninstall Boost"
    and $ports[0].licenseConcluded == "MIT"
    and ($binaries | length) == 1
    and ($binaries | all(.licenseConcluded == "MIT"))
