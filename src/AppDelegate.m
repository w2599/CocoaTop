#import "AppDelegate.h"
#import "PrivilegedClient.h"
#import "RootViewController.h"
#import "CocoaTopPreferences.h"

@implementation RootTabMaskController

-(instancetype)init {
    if (self = [super init]) {
        controller = [RootViewController new];
        [self addChildViewController: controller];
    }
    return self;
}

-(void)viewDidLoad {
    [super viewDidLoad];
    [self.view addSubview: controller.view];
    if (@available(iOS 11, *)) {
        mask = [[UIView alloc] initWithFrame:CGRectZero];
        mask.translatesAutoresizingMaskIntoConstraints = NO;
        if (@available(iOS 13, *)) {
            mask.backgroundColor = [UIColor colorWithDynamicProvider:^(UITraitCollection *collection) {
                if (collection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                    return [UIColor colorWithWhite:.31 alpha:.85];
                } else {
                    return [UIColor colorWithWhite:.75 alpha:.85];
                }
            }];
        } else {
            mask.backgroundColor = [UIColor colorWithWhite:.75 alpha:.85];
        }
        [self.view addSubview:mask];
        [self setBottomMaskVisible:[[[CocoaTopPreferences sharedPreferences] objectForKey:@"ShowFooter"] boolValue]];
    }
}

-(void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    if (@available(iOS 11, *)) {
        UIEdgeInsets insets = self.view.safeAreaInsets;
        if (!mask.hidden && insets.bottom != 0) {
            mask.frame = CGRectMake(0, self.view.bounds.size.height - insets.bottom, self.view.bounds.size.width, insets.bottom);
        } else {
            mask.frame = CGRectZero;
        }
    }
    if (controller.view != nil) {
        controller.view.frame = self.view.frame;
    }
}

- (void)setBottomMaskVisible:(BOOL)visible
{
    mask.hidden = !visible;
    [self.view setNeedsLayout];
}

@end

@implementation TopAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    //[UITableView appearance].estimatedRowHeight = 0;
    [UITableView appearance].rowHeight = 44;
    [UITableView appearance].sectionHeaderHeight = 23;
    [UITableView appearance].sectionFooterHeight = 23;
    if (@available(iOS 11, *)) {
        [UIScrollView appearance].contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    }
	// Create UIWindow
	self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = UIColor.systemBackgroundColor;
	// Allocate the navigation controller
	self.navigationController = [[UINavigationController alloc] initWithRootViewController:[RootTabMaskController new]];
	// Set the navigation controller as the window's root view controller and display.
	self.window.rootViewController = self.navigationController;
	[self.window makeKeyAndVisible];
	return YES;
}
// 进入后台释放辅助通道，回到前台时按需重新建立。
- (void)applicationDidEnterBackground:(UIApplication *)application
{
    CTStopPrivilegedHelper();
}

@end
