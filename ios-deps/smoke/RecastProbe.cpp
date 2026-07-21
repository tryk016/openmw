#include <DebugDraw.h>
#include <DetourNavMesh.h>
#include <DetourTileCache.h>
#include <Recast.h>

#include <cstdint>

#ifdef DT_POLYREF64
#    error "The iOS navigation ABI must use 32-bit Detour polygon references"
#endif

#ifdef DT_VIRTUAL_QUERYFILTER
#    error "The iOS navigation ABI must not use the virtual Detour query filter"
#endif

static_assert(sizeof(dtPolyRef) == sizeof(std::uint32_t),
    "Detour polygon references must remain 32-bit on iOS");

extern "C" int openmwIosRecastProbe()
{
    const float vertices[] = {
        -2.0f, 0.0f, -1.0f,
        3.0f, 4.0f, 5.0f,
    };
    float minimum[3] = {};
    float maximum[3] = {};
    rcCalcBounds(vertices, 2, minimum, maximum);
    if (minimum[0] != -2.0f || maximum[1] != 4.0f
        || maximum[2] != 5.0f)
    {
        return 1;
    }

    rcHeightfield* heightfield = rcAllocHeightfield();
    if (heightfield == nullptr)
        return 1;
    rcFreeHeightField(heightfield);

    dtNavMesh* navMesh = dtAllocNavMesh();
    if (navMesh == nullptr)
        return 1;
    dtFreeNavMesh(navMesh);

    dtTileCache* tileCache = dtAllocTileCache();
    if (tileCache == nullptr)
        return 1;
    dtFreeTileCache(tileCache);

    const unsigned int colour = duIntToCol(7, 191);
    if ((colour >> 24U) != 191U)
        return 1;

    return 0;
}

#ifndef OPENMW_IOS_PROBE_NO_MAIN
int main()
{
    return openmwIosRecastProbe();
}
#endif
