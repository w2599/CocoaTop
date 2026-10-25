#import <Foundation/Foundation.h>
#include <mach/mach.h>
#include <mach/notify.h>
#include <mach/task_special_ports.h>
#include <mach-o/dyld.h>
#include <mach/mach_init.h>
#include <spawn.h>
#include <pthread.h>
#include <sys/sysctl.h>
#include <sys/wait.h>
#include <signal.h>
#include <dlfcn.h>
#include <errno.h>
#include "sys/resource.h"
#include "sys/libproc.h"
#include "PrivilegedClient.h"

extern char **environ;
extern int posix_spawnattr_set_persona_np(const posix_spawnattr_t *, uid_t, uint32_t);
extern int posix_spawnattr_set_persona_uid_np(const posix_spawnattr_t *, uid_t);
extern int posix_spawnattr_set_persona_gid_np(const posix_spawnattr_t *, uid_t);

enum { CTMessageHello = 0x435400, CTMessageCall, CTMessageReply };
enum { CTOpInfo = 1, CTOpFDInfo, CTOpArgs = 4, CTOpTask, CTOpSignal, CTOpResources, CTOpResourceBatch };
static const uint32_t CTMaxReply = 16 * 1024 * 1024;
static const mach_msg_timeout_t CTTimeout = 3000;

typedef struct {
    mach_msg_header_t header;
    int operation, pid, flavor, fd;
    uint64_t argument;
    uint32_t capacity;
} CTRequest;

typedef struct {
    mach_msg_header_t header;
    mach_msg_body_t body;
    mach_msg_port_descriptor_t port;
    mach_msg_ool_descriptor_t data;
    int result, error;
} CTResponse;

typedef union {
    CTRequest request;
    CTResponse response;
    mach_no_senders_notification_t notification;
    uint8_t bytes[sizeof(CTResponse) + sizeof(mach_msg_max_trailer_t) + 128];
} CTReceiveBuffer;

static pthread_mutex_t CTLock = PTHREAD_MUTEX_INITIALIZER;
static mach_port_t CTService = MACH_PORT_NULL;
static mach_port_t CTReplyPort = MACH_PORT_NULL;
static CFAbsoluteTime CTLastFailure;

// 创建只有本进程持有接收权的私有通道。
static mach_port_t CTReceivePort(void)
{
    mach_port_t port = MACH_PORT_NULL;
    if (mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &port) != KERN_SUCCESS) return MACH_PORT_NULL;
    return port;
}

// 销毁接收权，释放队列中尚未处理的消息和端口。
static void CTDestroyReceivePort(mach_port_t port)
{
    if (port) mach_port_destroy(mach_task_self(), port);
}

// 初始化含任务端口和字节快照的响应消息。
static CTResponse CTMakeResponse(mach_port_t destination, mach_msg_id_t message, mach_msg_type_name_t disposition)
{
    CTResponse response = {0};
    response.header.msgh_bits = MACH_MSGH_BITS(disposition, 0) | MACH_MSGH_BITS_COMPLEX;
    response.header.msgh_size = sizeof(response);
    response.header.msgh_remote_port = destination;
    response.header.msgh_id = message;
    response.body.msgh_descriptor_count = 2;
    response.port.type = MACH_MSG_PORT_DESCRIPTOR;
    response.port.disposition = MACH_MSG_TYPE_COPY_SEND;
    response.data.type = MACH_MSG_OOL_DESCRIPTOR;
    response.data.copy = MACH_MSG_VIRTUAL_COPY;
    return response;
}

// 有限等待消息，避免辅助进程异常时让界面无限卡住。
static kern_return_t CTReceive(mach_port_t port, CTReceiveBuffer *buffer, mach_msg_timeout_t timeout)
{
    memset(buffer, 0, sizeof(*buffer));
    return mach_msg(&buffer->response.header, MACH_RCV_MSG | (timeout ? MACH_RCV_TIMEOUT : 0), 0,
                    sizeof(*buffer), port, timeout, MACH_PORT_NULL);
}

// 保留原有只读任务端口策略，不向界面返回额外的任务控制权限。
static kern_return_t CTLocalTaskForPID(pid_t pid, task_port_t *task)
{
    typedef kern_return_t (*ReadTask)(mach_port_t, pid_t, task_port_t *);
    static ReadTask readTask;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ readTask = (ReadTask)dlsym(RTLD_DEFAULT, "task_read_for_pid"); });
    *task = MACH_PORT_NULL;
    kern_return_t result = readTask ? readTask(mach_task_self(), pid, task) : task_for_pid(mach_task_self(), pid, task);
    if (result != KERN_SUCCESS && pid == 0 && !readTask)
        result = host_get_special_port(mach_host_self(), HOST_LOCAL_NODE, 4, task);
    if (result != KERN_SUCCESS) *task = MACH_PORT_NULL;
    return result;
}

// 在私有通道上处理固定的进程查询和信号，不接受任意命令或路径。
static void CTHandleRequest(const CTRequest *request)
{
    CTResponse response = CTMakeResponse(request->header.msgh_remote_port, CTMessageReply, MACH_MSG_TYPE_MOVE_SEND_ONCE);
    response.result = -1;
    response.error = EINVAL;
    void *bytes = NULL;
    mach_port_t task = MACH_PORT_NULL;
    if (request->pid >= 0 && request->capacity <= CTMaxReply) {
        bytes = request->capacity ? calloc(1, request->capacity) : NULL;
        if (request->capacity && !bytes) {
            response.error = ENOMEM;
        } else {
            errno = 0;
            switch (request->operation) {
                case CTOpResources:
                    if (request->capacity != sizeof(CTProcessResources)) { errno = EINVAL; break; }
                    CTCollectProcessResources(request->pid, bytes);
                    response.result = 0;
                    response.data.size = sizeof(CTProcessResources);
                    break;
                case CTOpResourceBatch:
                    if (request->capacity % sizeof(CTProcessResources)) { errno = EINVAL; break; }
                    response.result = CTCollectResourceBatch(bytes, request->capacity / sizeof(CTProcessResources));
                    if (response.result >= 0) response.data.size = response.result * sizeof(CTProcessResources);
                    break;
                case CTOpInfo:
                    response.result = proc_pidinfo(request->pid, request->flavor, request->argument, bytes, request->capacity);
                    if (response.result > 0 && bytes) response.data.size = MIN((uint32_t)response.result, request->capacity);
                    break;
                case CTOpFDInfo:
                    response.result = proc_pidfdinfo(request->pid, request->fd, request->flavor, bytes, request->capacity);
                    if (response.result > 0 && bytes) response.data.size = MIN((uint32_t)response.result, request->capacity);
                    break;
                case CTOpArgs: {
                    int mib[] = {CTL_KERN, KERN_PROCARGS2, request->pid};
                    size_t size = request->capacity;
                    response.result = sysctl(mib, 3, bytes, &size, NULL, 0);
                    if (!response.result && bytes) response.data.size = (uint32_t)size;
                    break;
                }
                case CTOpTask:
                    // 内核任务继续使用资源用量回退。
                    if (request->pid == 0) {
                        response.result = KERN_FAILURE;
                        break;
                    }
                    // 只读端口不可跨进程发送；传递普通端口，客户端立即降为只读。
                    if (request->pid == getpid()) {
                        // 获取可转交的自身端口，避免发送不可移动的 mach_task_self()。
                        response.result = task_get_special_port(mach_task_self(), TASK_KERNEL_PORT, &task);
                    } else {
                        response.result = task_for_pid(mach_task_self(), request->pid, &task);
                    }
                    response.port.name = task;
                    break;
                case CTOpSignal:
                    if (request->pid <= 1 || (request->flavor != SIGKILL && request->flavor != 0)) { errno = EPERM; break; }
                    response.result = kill(request->pid, request->flavor);
                    break;
                default: errno = EINVAL; break;
            }
            response.error = errno;
        }
    }
    response.data.address = bytes;
    mach_msg_return_t sent = mach_msg(&response.header, MACH_SEND_MSG | MACH_SEND_TIMEOUT,
                                      sizeof(response), 0, MACH_PORT_NULL, CTTimeout, MACH_PORT_NULL);
    if (sent != MACH_MSG_SUCCESS) mach_port_deallocate(mach_task_self(), request->header.msgh_remote_port);
    if (task) mach_port_deallocate(mach_task_self(), task);
    free(bytes);
}

// root 辅助模式只执行查询循环；客户端退出或关闭通道时自动结束。
int CTPrivilegedHelperMain(mach_port_t clientReceivePort)
{
    if (geteuid() != 0 || getegid() != 0) return EPERM;
    // 只从自己的父进程提取握手端口，不注册公共服务或改动特殊端口。
    pid_t parentPID = getppid();
    if (parentPID <= 1 || !clientReceivePort) return EINVAL;
    mach_port_t parentTask = MACH_PORT_NULL, parent = MACH_PORT_NULL;
    if (task_for_pid(mach_task_self(), parentPID, &parentTask) != KERN_SUCCESS) return EPERM;
    mach_msg_type_name_t type = 0;
    kern_return_t extracted = mach_port_extract_right(parentTask, clientReceivePort,
                                                      MACH_MSG_TYPE_MAKE_SEND, &parent, &type);
    mach_port_deallocate(mach_task_self(), parentTask);
    if (extracted != KERN_SUCCESS) return EPERM;
    mach_port_t service = CTReceivePort();
    if (!service) return ENOMEM;
    CTResponse hello = CTMakeResponse(parent, CTMessageHello, MACH_MSG_TYPE_COPY_SEND);
    hello.port.name = service;
    hello.port.disposition = MACH_MSG_TYPE_MAKE_SEND;
    if (mach_msg(&hello.header, MACH_SEND_MSG | MACH_SEND_TIMEOUT, sizeof(hello), 0,
                 MACH_PORT_NULL, CTTimeout, MACH_PORT_NULL) != MACH_MSG_SUCCESS) return EIO;
    mach_port_deallocate(mach_task_self(), parent);
    mach_port_t previous = MACH_PORT_NULL;
    mach_port_request_notification(mach_task_self(), service, MACH_NOTIFY_NO_SENDERS, 1,
                                   service, MACH_MSG_TYPE_MAKE_SEND_ONCE, &previous);
    if (previous) mach_port_deallocate(mach_task_self(), previous);
    for (;;) {
        CTReceiveBuffer buffer;
        if (CTReceive(service, &buffer, 0) != KERN_SUCCESS) break;
        CTRequest *request = &buffer.request;
        if (request->header.msgh_id == MACH_NOTIFY_NO_SENDERS) break;
        if (request->header.msgh_id == CTMessageCall && request->header.msgh_size == sizeof(*request) &&
            !(request->header.msgh_bits & MACH_MSGH_BITS_COMPLEX) && request->header.msgh_remote_port) {
            CTHandleRequest(request);
        } else {
            mach_msg_destroy(&request->header);
        }
    }
    CTDestroyReceivePort(service);
    return 0;
}

// 释放客户端唯一发送权，辅助进程收到无发送者通知后退出。
static void CTDisconnect(void)
{
    if (CTService) mach_port_deallocate(mach_task_self(), CTService);
    CTService = MACH_PORT_NULL;
    CTDestroyReceivePort(CTReplyPort);
    CTReplyPort = MACH_PORT_NULL;
}

// 在退出或进入后台时关闭当前辅助会话。
void CTStopPrivilegedHelper(void)
{
    pthread_mutex_lock(&CTLock);
    CTDisconnect();
    pthread_mutex_unlock(&CTLock);
}

// 启动独立 root 子进程，通过父进程专用接收端口建立私有会话。
static BOOL CTConnect(void)
{
    if (CTService) return YES;
    if (CFAbsoluteTimeGetCurrent() - CTLastFailure < 5) return NO;
    mach_port_t handshake = CTReceivePort();
    if (!handshake) return NO;
    posix_spawnattr_t attributes;
    int error = posix_spawnattr_init(&attributes);
    if (error) { CTDestroyReceivePort(handshake); return NO; }
    error = posix_spawnattr_set_persona_np(&attributes, 99, 1);
    if (!error) error = posix_spawnattr_set_persona_uid_np(&attributes, 0);
    if (!error) error = posix_spawnattr_set_persona_gid_np(&attributes, 0);
    if (!error) error = posix_spawnattr_setflags(&attributes, POSIX_SPAWN_CLOEXEC_DEFAULT);
    char path[PATH_MAX];
    uint32_t pathSize = sizeof(path);
    if (!error && _NSGetExecutablePath(path, &pathSize)) error = ENAMETOOLONG;
    if (!error) {
        char *name = strrchr(path, '/');
        if (!name || (size_t)(name + 1 - path) + sizeof("CocoaTopHelper") > sizeof(path)) error = ENAMETOOLONG;
        else strcpy(name + 1, "CocoaTopHelper");
    }
    char portName[32];
    snprintf(portName, sizeof(portName), "%u", handshake);
    char *arguments[] = {path, "--privileged-helper", portName, NULL};
    pid_t child = 0;
    if (!error) error = posix_spawn(&child, path, NULL, &attributes, arguments, environ);
    posix_spawnattr_destroy(&attributes);
    if (!error) {
        // 后台回收子进程，避免每次重新连接留下僵尸进程。
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            int status;
            while (waitpid(child, &status, 0) < 0 && errno == EINTR) {}
        });
        CTReceiveBuffer buffer;
        if (CTReceive(handshake, &buffer, CTTimeout) == KERN_SUCCESS) {
            CTResponse *hello = &buffer.response;
            if (hello->header.msgh_id == CTMessageHello && hello->header.msgh_size == sizeof(*hello) &&
                (hello->header.msgh_bits & MACH_MSGH_BITS_COMPLEX) && hello->body.msgh_descriptor_count == 2) {
                CTService = hello->port.name;
                hello->port.name = MACH_PORT_NULL;
            }
            mach_msg_destroy(&hello->header);
        }
    }
    CTDestroyReceivePort(handshake);
    if (!CTService) CTLastFailure = CFAbsoluteTimeGetCurrent();
    return CTService != MACH_PORT_NULL;
}

// 串行复用回复端口，异常时销毁以隔离迟到响应。
static int CTCall(CTRequest request, void *bytes, size_t *size, mach_port_t *task)
{
    pthread_mutex_lock(&CTLock);
    int result = -1, error = EIO;
    mach_port_t reply = MACH_PORT_NULL;
    if (CTConnect()) {
        if (!CTReplyPort) CTReplyPort = CTReceivePort();
        reply = CTReplyPort;
    }
    if (reply) {
        request.header.msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, MACH_MSG_TYPE_MAKE_SEND_ONCE);
        request.header.msgh_size = sizeof(request);
        request.header.msgh_remote_port = CTService;
        request.header.msgh_local_port = reply;
        request.header.msgh_id = CTMessageCall;
        CTReceiveBuffer buffer;
        if (mach_msg(&request.header, MACH_SEND_MSG | MACH_SEND_TIMEOUT, sizeof(request), 0,
                     MACH_PORT_NULL, CTTimeout, MACH_PORT_NULL) == KERN_SUCCESS &&
            CTReceive(reply, &buffer, CTTimeout) == KERN_SUCCESS) {
            CTResponse *response = &buffer.response;
            if (response->header.msgh_id == CTMessageReply && response->header.msgh_size == sizeof(*response) &&
                (response->header.msgh_bits & MACH_MSGH_BITS_COMPLEX) && response->body.msgh_descriptor_count == 2 &&
                response->data.size <= request.capacity) {
                result = response->result;
                error = response->error;
                if (bytes && response->data.size) memcpy(bytes, response->data.address, response->data.size);
                if (size) *size = response->data.size;
                if (task) { *task = response->port.name; response->port.name = MACH_PORT_NULL; }
            }
            mach_msg_destroy(&response->header);
            if (error == EIO && result == -1) {
                CTDisconnect();
                CTLastFailure = CFAbsoluteTimeGetCurrent();
            }
        } else {
            error = ETIMEDOUT;
            CTDisconnect();
            CTLastFailure = CFAbsoluteTimeGetCurrent();
        }
    }
    pthread_mutex_unlock(&CTLock);
    errno = error;
    return result;
}

// 读取跨用户进程信息，保持原 libproc 返回值约定。
int CTProcPIDInfo(int pid, int flavor, uint64_t arg, void *buffer, int size)
{
    if (size < 0 || (size && !buffer)) { errno = EINVAL; return 0; }
    CTRequest request = {.operation = CTOpInfo, .pid = pid, .flavor = flavor, .argument = arg, .capacity = size};
    int result = CTCall(request, buffer, NULL, NULL);
    return MAX(result, 0);
}

// 读取跨用户进程的文件描述符详情。
int CTProcPIDFDInfo(int pid, int fd, int flavor, void *buffer, int size)
{
    if (size < 0 || (size && !buffer)) { errno = EINVAL; return 0; }
    CTRequest request = {.operation = CTOpFDInfo, .pid = pid, .fd = fd, .flavor = flavor, .capacity = size};
    int result = CTCall(request, buffer, NULL, NULL);
    return MAX(result, 0);
}

// 详情页面只采集当前进程，将文件计数和资源用量合并为一次往返。
int CTReadProcessResources(pid_t pid, CTProcessResources *sample)
{
    if (!sample || pid < 0) { errno = EINVAL; return -1; }
    CTRequest request = {.operation = CTOpResources, .pid = pid, .capacity = sizeof(*sample)};
    size_t size = 0;
    int result = CTCall(request, sample, &size, NULL);
    if (result != 0 || size != sizeof(*sample)) return -1;
    return 0;
}

// 一轮刷新只取一次快照，失败时由调用方回退到单进程采集。
CTProcessResources *CTCopyResourceBatch(size_t capacity, size_t *count)
{
    if (!count || !capacity || capacity > CTMaxReply / sizeof(CTProcessResources)) return NULL;
    *count = 0;
    size_t bytes = capacity * sizeof(CTProcessResources);
    CTProcessResources *samples = malloc(bytes);
    if (!samples) return NULL;
    CTRequest request = {.operation = CTOpResourceBatch, .capacity = (uint32_t)bytes};
    size_t size = 0;
    int result = CTCall(request, samples, &size, NULL);
    if (result < 0 || (size_t)result > capacity || size != (size_t)result * sizeof(*samples)) {
        free(samples);
        return NULL;
    }
    *count = result;
    return samples;
}

// 读取其他用户的进程参数，不开放任意 sysctl 写入。
int CTProcArgs(int pid, void *buffer, size_t *size)
{
    if (!size || !buffer || *size > CTMaxReply) { errno = EINVAL; return -1; }
    CTRequest request = {.operation = CTOpArgs, .pid = pid, .capacity = (uint32_t)*size};
    return CTCall(request, buffer, size, NULL);
}

// 同用户任务优先直接读取，权限不足时获取辅助进程转交的只读端口。
kern_return_t CTTaskForPID(pid_t pid, task_port_t *task)
{
    if (!task || pid < 0) return KERN_INVALID_ARGUMENT;
    kern_return_t result = CTLocalTaskForPID(pid, task);
    if (result == KERN_SUCCESS && *task) return result;
    CTRequest request = {.operation = CTOpTask, .pid = pid};
    mach_port_t transferred = MACH_PORT_NULL;
    result = CTCall(request, NULL, NULL, &transferred);
    if (result == KERN_SUCCESS && transferred) {
        result = task_get_special_port(transferred, TASK_READ_PORT, task);
    } else if (result == KERN_SUCCESS) {
        result = KERN_FAILURE;
    }
    if (transferred) mach_port_deallocate(mach_task_self(), transferred);
    if (result != KERN_SUCCESS) *task = MACH_PORT_NULL;
    return result;
}

// 仅向明确的单个进程发送现有 KILL 操作，禁止进程组和系统启动进程。
int CTSignalProcess(pid_t pid, int signal)
{
    if (pid <= 1 || (signal != SIGKILL && signal != 0)) { errno = EPERM; return -1; }
    CTRequest request = {.operation = CTOpSignal, .pid = pid, .flavor = signal};
    return CTCall(request, NULL, NULL, NULL);
}
