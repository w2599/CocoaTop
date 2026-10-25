#pragma once
#include <sys/sysctl.h>
#include "sys/resource.h"

// 一次采样只传递计数和资源用量，不跨进程复制完整文件描述符列表。
typedef struct {
    pid_t pid;
    struct timeval startTime;
    uint64_t sampleTime;
    int usageResult;
    unsigned int files, sockets;
    struct rusage_info_v2 usage;
} CTProcessResources;

void CTCollectProcessResources(pid_t pid, CTProcessResources *sample);
int CTCollectResourceBatch(CTProcessResources *samples, size_t capacity);
int CTCompareResourcePID(const void *left, const void *right);
