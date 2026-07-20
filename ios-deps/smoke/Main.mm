#import <UIKit/UIKit.h>

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
    label.text = [NSString stringWithFormat:@"ios-deps bootstrap: PASS\nzlib %s",
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
