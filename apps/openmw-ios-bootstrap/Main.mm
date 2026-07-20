#import <UIKit/UIKit.h>
#import <os/log.h>

#include "BootstrapStatus.hpp"

#include <string>

namespace
{
    os_log_t bootstrapLog()
    {
        static os_log_t log = os_log_create("org.openmw.ios.bootstrap", "lifecycle");
        return log;
    }
}

@interface OpenMWBootstrapViewController : UIViewController
@end

@implementation OpenMWBootstrapViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor colorWithRed:0.035 green:0.067 blue:0.090 alpha:1.0];

    UILabel* title = [[UILabel alloc] initWithFrame:CGRectZero];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"OpenMW for iOS";
    title.textColor = [UIColor colorWithRed:0.86 green:0.72 blue:0.38 alpha:1.0];
    title.font = [UIFont preferredFontForTextStyle:UIFontTextStyleLargeTitle];
    title.adjustsFontForContentSizeCategory = YES;
    title.textAlignment = NSTextAlignmentCenter;

    const std::string statusText = OpenMW::IOS::bootstrapStatus();
    UILabel* status = [[UILabel alloc] initWithFrame:CGRectZero];
    status.translatesAutoresizingMaskIntoConstraints = NO;
    status.text = [NSString stringWithUTF8String:statusText.c_str()];
    status.textColor = UIColor.secondaryLabelColor;
    status.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    status.adjustsFontForContentSizeCategory = YES;
    status.numberOfLines = 0;
    status.textAlignment = NSTextAlignmentCenter;

    UIStackView* stack = [[UIStackView alloc] initWithArrangedSubviews:@[ title, status ]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 16.0;

    [self.view addSubview:stack];
    UILayoutGuide* safeArea = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [stack.centerXAnchor constraintEqualToAnchor:safeArea.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:safeArea.centerYAnchor],
        [stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:safeArea.leadingAnchor constant:24.0],
        [stack.trailingAnchor constraintLessThanOrEqualToAnchor:safeArea.trailingAnchor constant:-24.0],
    ]];

    os_log_info(bootstrapLog(), "G0 bootstrap view is visible");
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

@end

@interface OpenMWBootstrapAppDelegate : UIResponder <UIApplicationDelegate>

@property(strong, nonatomic) UIWindow* window;

@end

@implementation OpenMWBootstrapAppDelegate

- (BOOL)application:(UIApplication*)application
    didFinishLaunchingWithOptions:(NSDictionary<UIApplicationLaunchOptionsKey, id>*)launchOptions
{
    (void)application;
    (void)launchOptions;

    os_log_info(bootstrapLog(), "Application did finish launching");
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [[OpenMWBootstrapViewController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)applicationDidEnterBackground:(UIApplication*)application
{
    (void)application;
    os_log_info(bootstrapLog(), "Application entered background");
}

- (void)applicationWillEnterForeground:(UIApplication*)application
{
    (void)application;
    os_log_info(bootstrapLog(), "Application will enter foreground");
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication*)application
{
    (void)application;
    os_log_error(bootstrapLog(), "Application received a memory warning");
}

@end

int main(int argc, char* argv[])
{
    @autoreleasepool
    {
        os_log_info(bootstrapLog(), "Starting UIApplicationMain");
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(OpenMWBootstrapAppDelegate.class));
    }
}
