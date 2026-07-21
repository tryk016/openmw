#include <yaml-cpp/yaml.h>

#include <string>
#include <vector>

#ifndef YAML_CPP_STATIC_DEFINE
#    error "The yaml-cpp probe must use the static library ABI"
#endif

extern "C" int openmwIosYamlProbe()
{
    const YAML::Node document = YAML::Load(
        "enabled: true\n"
        "scale: 0.75\n"
        "profiles:\n"
        "  - [ios-low, touch]\n"
        "  - [ios-high, controller]\n");
    const auto profiles =
        document["profiles"].as<std::vector<std::vector<std::string>>>();
    if (!document["enabled"].as<bool>()
        || document["scale"].as<double>() != 0.75
        || profiles.size() != 2
        || profiles[1][1] != "controller")
    {
        return 1;
    }

    const std::vector<YAML::Node> documents =
        YAML::LoadAll("---\nname: first\n---\nname: second\n");
    if (documents.size() != 2
        || documents[1]["name"].as<std::string>() != "second")
    {
        return 1;
    }

    YAML::Node emitted;
    emitted["profile"] = "ios-low";
    emitted["limits"]["workers"] = 2;
    emitted.SetStyle(YAML::EmitterStyle::Block);
    YAML::Emitter output;
    output.SetMapFormat(YAML::Block);
    output << emitted;
    if (!output.good())
        return 1;

    const YAML::Node roundTrip = YAML::Load(output.c_str());
    if (roundTrip["limits"]["workers"].as<int>() != 2)
        return 1;

    try
    {
        (void)roundTrip["profile"].as<int>();
    }
    catch (const YAML::BadConversion&)
    {
        return 0;
    }
    return 1;
}

#ifndef OPENMW_IOS_PROBE_NO_MAIN
int main()
{
    return openmwIosYamlProbe();
}
#endif
