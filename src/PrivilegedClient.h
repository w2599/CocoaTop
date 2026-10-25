#pragma once
#include <mach/mach.h>
#include <sys/types.h>
#include <stdint.h>
#include <stddef.h>

struct rusage_info_v2;
int CTPrivilegedHelperMain(mach_port_t clientReceivePort);
void CTStopPrivilegedHelper(void);
int CTProcPIDInfo(int pid, int flavor, uint64_t arg, void *buffer, int size);
int CTProcPIDFDInfo(int pid, int fd, int flavor, void *buffer, int size);
int CTProcPIDRusage(int pid, int flavor, struct rusage_info_v2 *usage);
int CTProcArgs(int pid, void *buffer, size_t *size);
kern_return_t CTTaskForPID(pid_t pid, task_port_t *task);
int CTSignalProcess(pid_t pid, int signal);
