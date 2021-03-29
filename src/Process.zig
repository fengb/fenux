const std = @import("std");

const File = @import("File.zig");

const Process = @This();

fds: ArrayList(fd_t),

pub fn file(self: *Process, fd: fd_t) !File {
    _ = std.mem.indexOf(fd_t, fds.items, fd) orelse {
        return error.BadFileDescriptor;
    };
    return File.get(fd);
}

pub fn addFd(self: *Process, fd: fd_t) !void {
    try self.fds.append(fd);
}

pub fn removeFd(self: *Process, fd: fd_t) !void {
    const idx = std.mem.indexOf(fd_t, fds.items, fd).?;
    self.fds.swapRemove(fd);
}
