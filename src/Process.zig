const std = @import("std");

const File = @import("File.zig");
const T = @import("types.zig");

const Process = @This();

fds: std.ArrayList(T.Fd),

pub var active: ?*Process = null;

pub fn file(self: *Process, fd: T.Fd) !*File {
    _ = std.mem.indexOfScalar(T.Fd, self.fds.items, fd) orelse {
        return error.BadFileDescriptor;
    };
    return File.get(fd);
}

pub fn addFd(self: *Process, fd: T.Fd) !void {
    self.fds.append(fd) catch |err| switch (err) {
        error.OutOfMemory => return error.TooManyFileDescriptors,
    };
}

pub fn removeFd(self: *Process, fd: T.Fd) !void {
    const idx = std.mem.indexOfScalar(T.Fd, self.fds.items, fd) orelse return error.BadFileDescriptor;
    _ = self.fds.swapRemove(idx);
}

pub fn signal(self: *Process, sig: T.Signal) void {
    @panic("FIXME");
}
