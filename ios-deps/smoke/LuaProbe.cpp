#include <cstdlib>
#include <cstring>

extern "C"
{
#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>
}

#if LUA_VERSION_NUM != 501
#error "The iOS language foundation requires PUC Lua 5.1"
#endif

namespace
{
    struct AllocatorStats
    {
        unsigned allocations = 0;
        unsigned reallocations = 0;
        unsigned frees = 0;
    };

    void* probeAllocator(void* userData, void* pointer, std::size_t oldSize,
        std::size_t newSize)
    {
        (void)oldSize;
        auto& stats = *static_cast<AllocatorStats*>(userData);
        if (newSize == 0)
        {
            std::free(pointer);
            ++stats.frees;
            return nullptr;
        }
        if (pointer == nullptr)
            ++stats.allocations;
        else
            ++stats.reallocations;
        return std::realloc(pointer, newSize);
    }
}

extern "C" int openmwIosLuaProbe()
{
    AllocatorStats stats;
    lua_State* state = lua_newstate(probeAllocator, &stats);
    if (state == nullptr)
        return 1;

    luaL_openlibs(state);
    lua_getglobal(state, "_VERSION");
    const char* version = lua_tostring(state, -1);
    const bool correctVersion
        = version != nullptr && std::strcmp(version, "Lua 5.1") == 0;
    lua_pop(state, 1);
    if (!correctVersion)
    {
        lua_close(state);
        return 2;
    }

    constexpr char script[] = R"lua(
local mt = { __index = function(_, key) return "meta:" .. key end }
local values = setmetatable({ 3, 5, 8 }, mt)
assert(values.missing == "meta:missing")
local a, b, c = unpack(values)
assert(a == 3 and b == 5 and c == 8)

local coroutine_state = coroutine.create(function(seed)
    coroutine.yield(seed + 1)
    return seed + 2
end)
local ok, yielded = coroutine.resume(coroutine_state, 40)
assert(ok and yielded == 41)
ok, yielded = coroutine.resume(coroutine_state)
assert(ok and yielded == 42)

local error_ok, error_text = pcall(function() error("expected-error") end)
assert(not error_ok and string.find(error_text, "expected%-error"))

local process_ok, process_error = pcall(os.execute, "true")
assert(not process_ok and string.find(process_error, "unavailable on iOS"))

local library, load_error = package.loadlib(
    "/openmw/ios/no-dynamic-module.dylib", "luaopen_missing")
assert(library == nil)
assert(string.find(load_error, "dynamic libraries not enabled"))
)lua";

    const int loadResult = luaL_loadbuffer(
        state, script, sizeof(script) - 1, "ios-language-foundation");
    if (loadResult != 0)
    {
        lua_close(state);
        return 3;
    }
    const int runResult = lua_pcall(state, 0, 0, 0);
    lua_close(state);
    if (runResult != 0)
        return 4;
    if (stats.allocations == 0 || stats.reallocations == 0 || stats.frees == 0)
        return 5;
    return 0;
}

#ifndef OPENMW_IOS_PROBE_NO_MAIN
int main()
{
    return openmwIosLuaProbe();
}
#endif
