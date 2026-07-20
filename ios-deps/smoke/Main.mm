#import <UIKit/UIKit.h>

#include <array>
#include <cstring>

#include <SDL.h>
#include <lz4.h>
#include <zlib.h>

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
    const bool smokePassed = sdlInitResult == 0 && lz4RoundTripPassed;

    label.text = [NSString
        stringWithFormat:
            @"ios-deps base foundation: %@\n"
             "SDL %u.%u.%u (%d video drivers)\n"
             "LZ4 %s (round-trip %@)\n"
             "zlib %s",
            smokePassed ? @"PASS" : @"FAIL", sdlVersion.major,
            sdlVersion.minor, sdlVersion.patch, videoDriverCount,
            LZ4_versionString(), lz4RoundTripPassed ? @"PASS" : @"FAIL",
            zlibVersion()];
    [controller.view addSubview:label];

    self.window.rootViewController = controller;
    [self.window makeKeyAndVisible];
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
