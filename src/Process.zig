const std = @import("std");

const File = @import("File.zig");
const T = @import("types.zig");

const Process = @This();
fids: std.AutoHashMap(File.Id, void),

pub var active: ?*Process = null;

pub fn signal(self: *Process, sig: T.Signal) void {
    @panic("FIXME");
}
