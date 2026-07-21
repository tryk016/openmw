get_filename_component(_GL4ES_PREFIX "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

# GL4ES is pure C and does not call Foundation APIs. Its iOS backend does need
# the system OpenGLES implementation, which must remain visible to consumers of
# the static archive.
find_library(GL4ES_OPENGLES_FRAMEWORK OpenGLES REQUIRED)

if(NOT TARGET gl4es::GL)
    add_library(gl4es::GL STATIC IMPORTED)
    set_target_properties(gl4es::GL PROPERTIES
        IMPORTED_LOCATION "${_GL4ES_PREFIX}/lib/libGL.a"
        INTERFACE_INCLUDE_DIRECTORIES "${_GL4ES_PREFIX}/include"
        INTERFACE_LINK_LIBRARIES "${GL4ES_OPENGLES_FRAMEWORK}"
    )
endif()

set(gl4es_FOUND TRUE)
unset(_GL4ES_PREFIX)
