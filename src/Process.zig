const std = @import("std");

const File = @import("file.zig").File;
const T = @import("types.zig");

const Process = @This();

files: std.AutoHashMap(File, void),

pub var active: ?*Process = null;

pub fn signal(self: *Process, sig: T.Signal) void {
    @panic("FIXME");
}
