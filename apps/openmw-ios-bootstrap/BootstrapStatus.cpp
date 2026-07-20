#include "BootstrapStatus.hpp"

#include <TargetConditionals.h>

#include <string>

static_assert(__cplusplus >= 202002L, "The OpenMW iOS bootstrap requires C++20");

namespace OpenMW::IOS
{
    std::string bootstrapStatus()
    {
#if TARGET_OS_SIMULATOR
        return "G0 bootstrap running on iOS Simulator";
#else
        return "G0 bootstrap running on an iOS device";
#endif
    }
}
