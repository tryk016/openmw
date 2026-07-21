cmake_policy(PUSH)
cmake_policy(SET CMP0057 NEW)

include(CMakeFindDependencyMacro)
find_dependency(gl4es CONFIG)
find_dependency(Freetype)
find_dependency(JPEG)
find_dependency(PNG)
find_dependency(ZLIB)

include("${CMAKE_CURRENT_LIST_DIR}/osg-targets.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/osg-plugins.cmake")

# Left-to-right order for consumers that cannot use the exported targets.
set(${CMAKE_FIND_PACKAGE_NAME}_CORE_TARGETS
    unofficial::osg::osgAnimation
    unofficial::osg::osgParticle
    unofficial::osg::osgFX
    unofficial::osg::osgShadow
    unofficial::osg::osgSim
    unofficial::osg::osgViewer
    unofficial::osg::osgGA
    unofficial::osg::osgText
    unofficial::osg::osgDB
    unofficial::osg::osgUtil
    unofficial::osg::osg
    unofficial::osg::OpenThreads
)

set(${CMAKE_FIND_PACKAGE_NAME}_PLUGIN_TARGETS
    unofficial::osg::osgdb_bmp
    unofficial::osg::osgdb_dds
    unofficial::osg::osgdb_deprecated_osg
    unofficial::osg::osgdb_freetype
    unofficial::osg::osgdb_jpeg
    unofficial::osg::osgdb_osg
    unofficial::osg::osgdb_png
    unofficial::osg::osgdb_serializers_osg
    unofficial::osg::osgdb_tga
)

set(${CMAKE_FIND_PACKAGE_NAME}_VERSION "3.6.5")
cmake_policy(POP)
