#include <Foundation/Foundation.h>
#include <errno.h>
#import "PrivilegedClient.h"

// 独立工具只服务于启动它的客户端，不链接或启动 UIKit。
int main(int argc, char *argv[])
{
    if (argc != 3 || strcmp(argv[1], "--privileged-helper") != 0) return EINVAL;
    char *end = NULL;
    errno = 0;
    unsigned long port = strtoul(argv[2], &end, 10);
    if (errno || !port || port > UINT32_MAX || !end || *end) return EINVAL;
    return CTPrivilegedHelperMain((mach_port_t)port);
}
