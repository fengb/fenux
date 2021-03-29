const std = @import("std");

const Process = @import("Process.zig");

const impls = struct {
    pub fn @"000 restart"() usize {
        unreachable;
    }

    pub fn @"001 exit"(process: *Process, arg: usize) void {
        unreachable;
    }

    pub fn @"002 fork"(process: *Process) usize {
        unreachable;
    }

    pub fn @"003 read"(process: *Process, fd: fd_t, buf: [*]u8, count: usize) !usize {
        const file = try process.file(fd);
        return file.read(buf[0..count]);
    }

    pub fn @"004 write"(process: *Process, fd: fd_t, buf: [*]u8, count: usize) !usize {
        const file = try process.file(fd);
        return file.write(buf[0..count]);
    }

    pub fn @"005 open"(process: *Process, path: [*:0]const u8, flags: u32, perm: mode_t) !fd_t {
        const fd = File.open(std.mem.spanZ(path), flags, perm);
        try process.addFd(fd);
        return fd;
    }

    pub fn @"006 close"(process: *Process, fd: fd_t) !usize {
        const file = try process.file(fd);
        try process.removeFd(fd);
        return 0;
    }
};
