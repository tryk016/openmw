cmake_minimum_required(VERSION 3.25)
project(openmw_ios_lua VERSION 5.1.5 LANGUAGES C)

set(lua_sources
    src/lapi.c
    src/lauxlib.c
    src/lbaselib.c
    src/lcode.c
    src/ldblib.c
    src/ldebug.c
    src/ldo.c
    src/ldump.c
    src/lfunc.c
    src/lgc.c
    src/linit.c
    src/liolib.c
    src/llex.c
    src/lmathlib.c
    src/lmem.c
    src/loadlib.c
    src/lobject.c
    src/lopcodes.c
    src/loslib.c
    src/lparser.c
    src/lstate.c
    src/lstring.c
    src/lstrlib.c
    src/ltable.c
    src/ltablib.c
    src/ltm.c
    src/lundump.c
    src/lvm.c
    src/lzio.c
)

add_library(lua STATIC ${lua_sources})
target_compile_features(lua PRIVATE c_std_99)
target_compile_definitions(lua PRIVATE LUA_ANSI=1)
target_include_directories(lua
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src>
        $<INSTALL_INTERFACE:include>
)
set_target_properties(lua PROPERTIES
    OUTPUT_NAME lua
    POSITION_INDEPENDENT_CODE ON
)

install(TARGETS lua
    EXPORT unofficial-lua-targets
    ARCHIVE DESTINATION lib
)
install(FILES
    src/lua.h
    src/luaconf.h
    src/lauxlib.h
    src/lualib.h
    lua.hpp
    DESTINATION include
)
install(EXPORT unofficial-lua-targets
    FILE unofficial-lua-config.cmake
    NAMESPACE unofficial::lua::
    DESTINATION share/unofficial-lua
)
