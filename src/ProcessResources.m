#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <limits.h>
#include <mach/mach_time.h>
#include "ProcessResources.h"
#include "sys/proc_info.h"
#include "sys/libproc.h"

// 辅助进程串行复用缓冲区，文件数增长时扩容并重新读取。
static void CTCollectFileCounts(pid_t pid, CTProcessResources *sample)
{
    static struct proc_fdinfo *buffer;
    static int capacity;
    if (!buffer) {
        capacity = 256 * PROC_PIDLISTFD_SIZE;
        buffer = malloc(capacity);
        if (!buffer) { capacity = 0; return; }
    }
    for (;;) {
        int size = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, buffer, capacity);
        if (size <= 0) return;
        if (size >= capacity) {
            if (capacity >= 16 * 1024 * 1024) return;
            int next = capacity * 2;
            void *grown = realloc(buffer, next);
            if (!grown) return;
            buffer = grown;
            capacity = next;
            continue;
        }
        for (int i = 0; i < size / PROC_PIDLISTFD_SIZE; i++) {
            switch (buffer[i].proc_fdtype) {
                case PROX_FDTYPE_SOCKET: sample->sockets++; /* 同时计入文件数。 */
                case PROX_FDTYPE_VNODE:
                case PROX_FDTYPE_PIPE:
                case PROX_FDTYPE_KQUEUE: sample->files++; break;
            }
        }
        return;
    }
}

// 在采集处记录时钟，保证 CPU 差分与资源快照对应。
void CTCollectProcessResources(pid_t pid, CTProcessResources *sample)
{
    memset(sample, 0, sizeof(*sample));
    sample->pid = pid;
    CTCollectFileCounts(pid, sample);
    sample->sampleTime = mach_absolute_time();
    sample->usageResult = proc_pid_rusage(pid, RUSAGE_INFO_V2, &sample->usage);
}

// 按 PID 排序，客户端用二分查找匹配本轮快照。
int CTCompareResourcePID(const void *left, const void *right)
{
    pid_t a = ((const CTProcessResources *)left)->pid;
    pid_t b = ((const CTProcessResources *)right)->pid;
    return (a > b) - (a < b);
}

// 批量采集当前进程，进程数增长或退出时不返回截断快照。
int CTCollectResourceBatch(CTProcessResources *samples, size_t capacity)
{
    int mib[] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
    if (!capacity || capacity > INT_MAX / sizeof(struct kinfo_proc)) { errno = EINVAL; return -1; }
    size_t size = capacity * sizeof(struct kinfo_proc);
    struct kinfo_proc *processes = malloc(size);
    if (!processes) { errno = ENOMEM; return -1; }
    if (sysctl(mib, 4, processes, &size, NULL, 0) != 0) { free(processes); return -1; }
    size_t count = size / sizeof(*processes);
    for (size_t i = 0; i < count; i++) {
        CTCollectProcessResources(processes[i].kp_proc.p_pid, &samples[i]);
        samples[i].startTime = processes[i].kp_proc.p_starttime;
    }
    free(processes);
    qsort(samples, count, sizeof(*samples), CTCompareResourcePID);
    return (int)count;
}
