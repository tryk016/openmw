#include <DebugDraw.h>
#include <DetourAlloc.h>
#include <DetourDebugDraw.h>
#include <DetourNavMesh.h>
#include <DetourNavMeshBuilder.h>
#include <DetourNavMeshQuery.h>
#include <DetourTileCache.h>
#include <Recast.h>

#include <cstdint>
#include <memory>

#ifdef DT_POLYREF64
#    error "The iOS navigation ABI must use 32-bit Detour polygon references"
#endif

#ifdef DT_VIRTUAL_QUERYFILTER
#    error "The iOS navigation ABI must not use the virtual Detour query filter"
#endif

static_assert(sizeof(dtPolyRef) == sizeof(std::uint32_t),
    "Detour polygon references must remain 32-bit on iOS");

namespace
{
    enum ProbeResult
    {
        Pass = 0,
        InvalidGeometryBounds = 10,
        InvalidRasterGrid = 11,
        HeightfieldAllocationFailed = 12,
        HeightfieldCreationFailed = 13,
        WalkableClassificationFailed = 14,
        RasterizationFailed = 15,
        NoWalkableSpans = 16,
        NavMeshDataCreationFailed = 20,
        NavMeshAllocationFailed = 21,
        NavMeshInitializationFailed = 22,
        NavMeshQueryAllocationFailed = 23,
        NavMeshQueryInitializationFailed = 24,
        StartPolygonLookupFailed = 25,
        EndPolygonLookupFailed = 26,
        PolygonSelectionFailed = 27,
        PathQueryFailed = 28,
        InvalidPathResult = 29,
        DebugDrawCallbacksFailed = 30,
        TileCacheAllocationFailed = 40,
    };

    struct HeightfieldDeleter
    {
        void operator()(rcHeightfield* value) const
        {
            rcFreeHeightField(value);
        }
    };

    struct NavDataDeleter
    {
        void operator()(unsigned char* value) const
        {
            dtFree(value);
        }
    };

    struct NavMeshDeleter
    {
        void operator()(dtNavMesh* value) const
        {
            dtFreeNavMesh(value);
        }
    };

    struct NavMeshQueryDeleter
    {
        void operator()(dtNavMeshQuery* value) const
        {
            dtFreeNavMeshQuery(value);
        }
    };

    struct TileCacheDeleter
    {
        void operator()(dtTileCache* value) const
        {
            dtFreeTileCache(value);
        }
    };

    class CountingDebugDraw final : public duDebugDraw
    {
    public:
        void depthMask(bool enabled) override
        {
            ++m_depthMaskCalls;
            m_lastDepthMask = enabled;
        }

        void texture(bool) override {}

        void begin(duDebugDrawPrimitives primitive, float) override
        {
            if (m_insidePrimitive)
                m_invalidSequence = true;
            m_insidePrimitive = true;
            ++m_beginCalls;
            if (primitive == DU_DRAW_TRIS)
                m_sawTriangles = true;
        }

        void vertex(const float*, unsigned int) override
        {
            countVertex();
        }

        void vertex(float, float, float, unsigned int) override
        {
            countVertex();
        }

        void vertex(const float*, unsigned int, const float*) override
        {
            countVertex();
        }

        void vertex(
            float, float, float, unsigned int, float, float) override
        {
            countVertex();
        }

        void end() override
        {
            if (!m_insidePrimitive)
                m_invalidSequence = true;
            m_insidePrimitive = false;
            ++m_endCalls;
        }

        bool passed() const
        {
            return !m_invalidSequence && !m_insidePrimitive
                && m_beginCalls >= 3 && m_beginCalls == m_endCalls
                && m_vertexCalls >= 6 && m_sawTriangles
                && m_depthMaskCalls >= 2 && m_lastDepthMask;
        }

    private:
        void countVertex()
        {
            if (!m_insidePrimitive)
                m_invalidSequence = true;
            ++m_vertexCalls;
        }

        int m_depthMaskCalls = 0;
        int m_beginCalls = 0;
        int m_endCalls = 0;
        int m_vertexCalls = 0;
        bool m_insidePrimitive = false;
        bool m_invalidSequence = false;
        bool m_sawTriangles = false;
        bool m_lastDepthMask = false;
    };
}

extern "C" int openmwIosRecastProbe()
{
    constexpr float geometryVertices[] = {
        0.0f, 0.0f, 0.0f,
        8.0f, 0.0f, 0.0f,
        8.0f, 0.0f, 4.0f,
        0.0f, 0.0f, 4.0f,
    };
    constexpr int geometryTriangles[] = {
        0, 2, 1,
        0, 3, 2,
    };
    float minimum[3] = {};
    float maximum[3] = {};
    rcCalcBounds(geometryVertices, 4, minimum, maximum);
    if (minimum[0] != 0.0f || minimum[1] != 0.0f
        || minimum[2] != 0.0f || maximum[0] != 8.0f
        || maximum[1] != 0.0f || maximum[2] != 4.0f)
    {
        return InvalidGeometryBounds;
    }

    constexpr float cellSize = 1.0f;
    constexpr float cellHeight = 0.5f;
    int gridWidth = 0;
    int gridHeight = 0;
    rcCalcGridSize(
        minimum, maximum, cellSize, &gridWidth, &gridHeight);
    if (gridWidth != 8 || gridHeight != 4)
        return InvalidRasterGrid;

    minimum[1] = -1.0f;
    maximum[1] = 1.0f;
    std::unique_ptr<rcHeightfield, HeightfieldDeleter> heightfield(
        rcAllocHeightfield());
    if (!heightfield)
        return HeightfieldAllocationFailed;
    rcContext context;
    if (!rcCreateHeightfield(&context, *heightfield, gridWidth, gridHeight,
            minimum, maximum, cellSize, cellHeight))
    {
        return HeightfieldCreationFailed;
    }

    unsigned char triangleAreas[] = { RC_NULL_AREA, RC_NULL_AREA };
    rcMarkWalkableTriangles(&context, 45.0f, geometryVertices, 4,
        geometryTriangles, 2, triangleAreas);
    if (triangleAreas[0] != RC_WALKABLE_AREA
        || triangleAreas[1] != RC_WALKABLE_AREA)
    {
        return WalkableClassificationFailed;
    }
    if (!rcRasterizeTriangles(&context, geometryVertices, 4,
            geometryTriangles, triangleAreas, 2, *heightfield, 1))
    {
        return RasterizationFailed;
    }

    int walkableSpanCount = 0;
    for (int column = 0; column < gridWidth * gridHeight; ++column)
    {
        for (const rcSpan* span = heightfield->spans[column]; span;
             span = span->next)
        {
            if (span->area == RC_WALKABLE_AREA)
                ++walkableSpanCount;
        }
    }
    if (walkableSpanCount == 0)
        return NoWalkableSpans;

    constexpr unsigned short nullIndex = RC_MESH_NULL_IDX;
    constexpr unsigned short navVertices[] = {
        0, 0, 0,
        4, 0, 0,
        4, 0, 4,
        0, 0, 4,
        8, 0, 0,
        8, 0, 4,
    };
    constexpr unsigned short navPolygons[] = {
        0, 3, 2, 1,
        nullIndex, nullIndex, 1, nullIndex,
        1, 2, 5, 4,
        0, nullIndex, nullIndex, nullIndex,
    };
    constexpr unsigned short polygonFlags[] = { 1, 1 };
    constexpr unsigned char polygonAreas[] = { 0, 0 };

    dtNavMeshCreateParams params = {};
    params.verts = navVertices;
    params.vertCount = 6;
    params.polys = navPolygons;
    params.polyFlags = polygonFlags;
    params.polyAreas = polygonAreas;
    params.polyCount = 2;
    params.nvp = 4;
    params.bmin[0] = 0.0f;
    params.bmin[1] = 0.0f;
    params.bmin[2] = 0.0f;
    params.bmax[0] = 8.0f;
    params.bmax[1] = 2.0f;
    params.bmax[2] = 4.0f;
    params.walkableHeight = 2.0f;
    params.walkableRadius = 0.5f;
    params.walkableClimb = 0.5f;
    params.cs = 1.0f;
    params.ch = 1.0f;
    params.buildBvTree = true;

    unsigned char* rawNavData = nullptr;
    int navDataSize = 0;
    const bool navDataCreated
        = dtCreateNavMeshData(&params, &rawNavData, &navDataSize);
    std::unique_ptr<unsigned char, NavDataDeleter> navData(rawNavData);
    if (!navDataCreated || !navData || navDataSize <= 0)
        return NavMeshDataCreationFailed;

    std::unique_ptr<dtNavMesh, NavMeshDeleter> navMesh(dtAllocNavMesh());
    if (!navMesh)
        return NavMeshAllocationFailed;
    if (dtStatusFailed(
            navMesh->init(navData.get(), navDataSize, DT_TILE_FREE_DATA)))
    {
        return NavMeshInitializationFailed;
    }
    navData.release();

    std::unique_ptr<dtNavMeshQuery, NavMeshQueryDeleter> navQuery(
        dtAllocNavMeshQuery());
    if (!navQuery)
        return NavMeshQueryAllocationFailed;
    if (dtStatusFailed(navQuery->init(navMesh.get(), 64)))
        return NavMeshQueryInitializationFailed;

    const float startPosition[] = { 1.0f, 0.0f, 2.0f };
    const float endPosition[] = { 7.0f, 0.0f, 2.0f };
    const float searchExtents[] = { 1.0f, 2.0f, 1.0f };
    dtQueryFilter filter;
    dtPolyRef startRef = 0;
    dtPolyRef endRef = 0;
    float nearestStart[3] = {};
    float nearestEnd[3] = {};
    if (dtStatusFailed(navQuery->findNearestPoly(startPosition,
            searchExtents, &filter, &startRef, nearestStart))
        || startRef == 0)
    {
        return StartPolygonLookupFailed;
    }
    if (dtStatusFailed(navQuery->findNearestPoly(endPosition,
            searchExtents, &filter, &endRef, nearestEnd))
        || endRef == 0)
    {
        return EndPolygonLookupFailed;
    }
    if (startRef == endRef)
        return PolygonSelectionFailed;

    dtPolyRef path[4] = {};
    int pathCount = 0;
    if (dtStatusFailed(navQuery->findPath(startRef, endRef, nearestStart,
            nearestEnd, &filter, path, &pathCount, 4)))
    {
        return PathQueryFailed;
    }
    if (pathCount != 2 || path[0] != startRef || path[1] != endRef)
        return InvalidPathResult;

    CountingDebugDraw debugDraw;
    duDebugDrawNavMesh(&debugDraw, *navMesh, 0);
    if (!debugDraw.passed())
        return DebugDrawCallbacksFailed;

    std::unique_ptr<dtTileCache, TileCacheDeleter> tileCache(
        dtAllocTileCache());
    if (!tileCache)
        return TileCacheAllocationFailed;

    return Pass;
}

#ifndef OPENMW_IOS_PROBE_NO_MAIN
int main()
{
    return openmwIosRecastProbe();
}
#endif
