#import <UIKit/UIKit.h>
#include <sys/sysctl.h>
#include <errno.h>
#import "AppDelegate.h"
#import "PrivilegedClient.h"

// 校验实际、有效和保存身份，禁止以 root 或遗留提权身份进入 UIKit。
static BOOL CTIsMobileUser(void)
{
    struct kinfo_proc info = {0};
    size_t length = sizeof(info);
    int mib[] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};
    if (sysctl(mib, 4, &info, &length, NULL, 0) != 0 || length != sizeof(info)) return NO;
    return getuid() == 501 && geteuid() == 501 && getgid() == 501 && getegid() == 501 &&
        info.kp_eproc.e_pcred.p_svuid == 501 && info.kp_eproc.e_pcred.p_svgid == 501;
}

// 界面程序始终使用 mobile 身份，不承接 root 辅助模式。
int main(int argc, char *argv[])
{
    if (!CTIsMobileUser()) {
        fprintf(stderr, "CocoaTop 界面只允许以 mobile 身份启动\n");
        return EPERM;
    }
    atexit(CTStopPrivilegedHelper);
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(TopAppDelegate.class));
    }
}
