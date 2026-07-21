#include <BulletCollision/CollisionShapes/btBvhTriangleMeshShape.h>
#include <BulletCollision/CollisionShapes/btTriangleMesh.h>
#include <LinearMath/btConvexHullComputer.h>
#include <LinearMath/btThreads.h>

#include <array>
#include <cmath>
#include <thread>
#include <type_traits>

#ifndef BT_USE_DOUBLE_PRECISION
#    error "The Bullet probe must use the double-precision ABI"
#endif

#if !defined(BT_THREADSAFE) || BT_THREADSAFE != 1
#    error "The Bullet probe requires its thread-safe ABI"
#endif

static_assert(std::is_same_v<btScalar, double>,
    "Bullet btScalar must be double on iOS");

extern "C" int openmwIosBulletProbe()
{
    if (btGetCurrentThreadIndex() != 0 || !btIsMainThread())
        return 1;

    std::array<unsigned int, 2> workerIndices{};
    std::thread firstWorker(
        [&workerIndices] { workerIndices[0] = btGetCurrentThreadIndex(); });
    std::thread secondWorker(
        [&workerIndices] { workerIndices[1] = btGetCurrentThreadIndex(); });
    firstWorker.join();
    secondWorker.join();
    if (workerIndices[0] == 0 || workerIndices[1] == 0
        || workerIndices[0] == workerIndices[1])
    {
        return 1;
    }

    const btScalar tetrahedron[] = {
        0.0, 0.0, 0.0,
        1.0, 0.0, 0.0,
        0.0, 1.0, 0.0,
        0.0, 0.0, 1.0,
    };
    btConvexHullComputer hull;
    hull.compute(tetrahedron, 3 * sizeof(btScalar), 4, 0.0, 0.0);
    if (hull.vertices.size() != 4 || hull.faces.size() != 4)
        return 1;

    btTriangleMesh mesh;
    mesh.addTriangle(
        btVector3(0.0, 0.0, 0.0),
        btVector3(1.0, 0.0, 0.0),
        btVector3(0.0, 1.0, 0.0));
    if (mesh.getNumTriangles() != 1)
        return 1;

    btBvhTriangleMeshShape shape(&mesh, true);
    btVector3 minimum;
    btVector3 maximum;
    shape.getAabb(btTransform::getIdentity(), minimum, maximum);
    for (int axis = 0; axis < 3; ++axis)
    {
        if (!std::isfinite(minimum[axis])
            || !std::isfinite(maximum[axis])
            || minimum[axis] > maximum[axis])
        {
            return 1;
        }
    }
    return 0;
}

#ifndef OPENMW_IOS_PROBE_NO_MAIN
int main()
{
    return openmwIosBulletProbe();
}
#endif
