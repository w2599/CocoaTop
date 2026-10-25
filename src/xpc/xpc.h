// Copyright (c) 2009-2011 Apple Inc. All rights reserved. 

#ifndef COCOATOP_XPC_COMPAT_H
#define COCOATOP_XPC_COMPAT_H

typedef void *xpc_pipe_t;

__attribute__((weak_import))
void xpc_pipe_invalidate(xpc_pipe_t pipe);

__attribute__((weak_import))
int xpc_pipe_routine(xpc_pipe_t pipe, xpc_object_t message, xpc_object_t *reply);

__attribute__((weak_import))
xpc_pipe_t xpc_pipe_create_from_port(mach_port_t port, int flags);

#endif // COCOATOP_XPC_COMPAT_H
