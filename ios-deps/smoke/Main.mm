#import <UIKit/UIKit.h>
#import <os/log.h>

#include <array>
#include <cstddef>
#include <cstdio>
#include <cstring>

#include <SDL.h>
#include <ft2build.h>
#include FT_CONFIG_OPTIONS_H
#include FT_FREETYPE_H
#include <jpeglib.h>
#include <lz4.h>
#include <png.h>
#include <sqlite3.h>
#include <turbojpeg.h>
#include <zlib.h>

#ifndef FT_CONFIG_OPTION_USE_PNG
#error "The locked FreeType build must enable PNG bitmap support"
#endif
#ifndef FT_CONFIG_OPTION_SYSTEM_ZLIB
#error "The locked FreeType build must use the external zlib package"
#endif

extern "C" int openmwIosYamlProbe();
extern "C" int openmwIosSQLiteProbe();
extern "C" int openmwIosBulletProbe();
extern "C" int openmwIosIcuProbe();
extern "C" int openmwIosLuaProbe();
extern "C" int openmwIosRecastProbe();

@interface OpenMWDepsSmokeDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow* window;
@end

@implementation OpenMWDepsSmokeDelegate

- (BOOL)application:(UIApplication*)application
    didFinishLaunchingWithOptions:(NSDictionary*)launchOptions
{
    (void)application;
    (void)launchOptions;

    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    UIViewController* controller = [[UIViewController alloc] init];
    controller.view.backgroundColor = [UIColor colorWithRed:0.025
                                                      green:0.055
                                                       blue:0.08
                                                      alpha:1.0];

    UILabel* label = [[UILabel alloc] initWithFrame:controller.view.bounds];
    label.autoresizingMask
        = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 0;
    label.textColor = [UIColor colorWithRed:0.92 green:0.75 blue:0.30 alpha:1.0];
    label.font = [UIFont monospacedSystemFontOfSize:18 weight:UIFontWeightMedium];

    SDL_SetMainReady();
    const int sdlInitResult = SDL_Init(0);
    SDL_version sdlVersion = {};
    SDL_GetVersion(&sdlVersion);
    const int videoDriverCount = SDL_GetNumVideoDrivers();
    SDL_Quit();

    constexpr char source[] = "OpenMW iOS dependency smoke";
    std::array<char, LZ4_COMPRESSBOUND(sizeof(source))> compressed = {};
    std::array<char, sizeof(source)> restored = {};
    const int compressedSize = LZ4_compress_default(
        source, compressed.data(), sizeof(source), compressed.size());
    const int restoredSize
        = compressedSize > 0
        ? LZ4_decompress_safe(compressed.data(), restored.data(),
              compressedSize, restored.size())
        : -1;
    const bool lz4RoundTripPassed
        = restoredSize == sizeof(source)
        && std::memcmp(source, restored.data(), sizeof(source)) == 0;

    FT_Library freeType = nullptr;
    const FT_Error freeTypeInitResult = FT_Init_FreeType(&freeType);
    FT_Int freeTypeMajor = 0;
    FT_Int freeTypeMinor = 0;
    FT_Int freeTypePatch = 0;
    if (freeTypeInitResult == 0)
    {
        FT_Library_Version(
            freeType, &freeTypeMajor, &freeTypeMinor, &freeTypePatch);
        FT_Done_FreeType(freeType);
    }

    png_structp pngReader = png_create_read_struct(
        PNG_LIBPNG_VER_STRING, nullptr, nullptr, nullptr);
    const bool pngPassed = pngReader != nullptr;
    if (pngReader != nullptr)
        png_destroy_read_struct(&pngReader, nullptr, nullptr);

    jpeg_decompress_struct jpegDecoder = {};
    jpeg_error_mgr jpegError = {};
    jpegDecoder.err = jpeg_std_error(&jpegError);
    jpeg_create_decompress(&jpegDecoder);
    jpeg_destroy_decompress(&jpegDecoder);

    tjhandle turboJpegDecoder = tj3Init(TJINIT_DECOMPRESS);
    const bool turboJpegPassed = turboJpegDecoder != nullptr;
    if (turboJpegDecoder != nullptr)
        tj3Destroy(turboJpegDecoder);

    const bool imageFoundationPassed = freeTypeInitResult == 0 && pngPassed
        && turboJpegPassed;
    const bool yamlPassed = openmwIosYamlProbe() == 0;
    const bool sqlitePassed = openmwIosSQLiteProbe() == 0;
    const bool bulletPassed = openmwIosBulletProbe() == 0;
    const bool recastPassed = openmwIosRecastProbe() == 0;
    const int luaResult = openmwIosLuaProbe();
    const int icuResult = openmwIosIcuProbe();
    const bool luaPassed = luaResult == 0;
    const bool icuPassed = icuResult == 0;
    const bool smokePassed
        = sdlInitResult == 0 && lz4RoundTripPassed && imageFoundationPassed
        && yamlPassed && sqlitePassed && bulletPassed && recastPassed
        && luaPassed && icuPassed;

    label.text = [NSString
        stringWithFormat:
            @"ios-deps language foundation: %@\n"
             "SDL %u.%u.%u (%d video drivers)\n"
             "LZ4 %s (round-trip %@)\n"
             "zlib %s\n"
             "FreeType %d.%d.%d\n"
             "libpng %s\n"
             "libjpeg-turbo %s\n"
             "yaml-cpp %@\n"
             "SQLite %s %@\n"
             "Bullet 3.17 %@\n"
             "RecastNavigation 1.6.0 %@\n"
             "PUC Lua 5.1.5 %@ (result %d)\n"
             "ICU 70.1 %@ (result %d)",
            smokePassed ? @"PASS" : @"FAIL", sdlVersion.major,
            sdlVersion.minor, sdlVersion.patch, videoDriverCount,
            LZ4_versionString(), lz4RoundTripPassed ? @"PASS" : @"FAIL",
            zlibVersion(), freeTypeMajor, freeTypeMinor, freeTypePatch,
            png_get_libpng_ver(nullptr),
            turboJpegPassed ? "PASS" : "FAIL",
            yamlPassed ? @"PASS" : @"FAIL",
            sqlite3_libversion(),
            sqlitePassed ? @"PASS" : @"FAIL",
            bulletPassed ? @"PASS" : @"FAIL",
            recastPassed ? @"PASS" : @"FAIL",
            luaPassed ? @"PASS" : @"FAIL", luaResult,
            icuPassed ? @"PASS" : @"FAIL", icuResult];
    [controller.view addSubview:label];

    self.window.rootViewController = controller;
    [self.window makeKeyAndVisible];
    os_log_t runtimeLog =
        os_log_create("org.openmw.ios.deps-smoke", "runtime");
    os_log_info(runtimeLog,
        "language foundation %{public}s lua=%{public}d icu=%{public}d",
        smokePassed ? "PASS" : "FAIL", luaResult, icuResult);
    return YES;
}

@end

int main(int argc, char* argv[])
{
    @autoreleasepool
    {
        return UIApplicationMain(
            argc, argv, nil, NSStringFromClass(OpenMWDepsSmokeDelegate.class));
    }
}
