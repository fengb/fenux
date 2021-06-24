const std = @import("std");

const File = @import("File.zig");
const Memory = @import("Memory.zig");
const Thread = @import("Thread.zig");
const T = @import("types.zig");
const util = @import("util.zig");

const Process = @This();
id: Id,
parent_id: Id,
memory: Memory,
tids: std.AutoHashMap(Thread.Id, void),
fids: std.AutoHashMap(File.Id, void),
status: enum { active, defunct },

var all: std.AutoHashMap(Id, Process) = undefined;
var incr: util.AutoIncr(Id, 2) = .{};

pub fn fork(thread: *Thread) !*Process {
    const parent = thread.pid.process();

    var fids = try parent.fids.clone();
    {
        var iter = fids.iterator();
        while (iter.next()) |entry| {
            entry.key.file().retain();
        }
    }
    errdefer {
        var iter = fids.iterator();
        while (iter.next()) |entry| {
            entry.key.file().release();
        }
        fids.deinit();
    }

    const pid = incr.next(all);
    try all.putNoClobber(pid, .{
        .id = pid,
        .parent_id = parent.id,
        .memory = parent.memory,
        .tids = undefined,
        .fids = fids,
        .status = .active,
    });
    errdefer _ = all.remove(pid);

    const result = pid.process();

    const tid = try Thread.scheduler.spawn(pid);
    try result.tids.putNoClobber(tid, {});

    return result;
}

pub fn signal(self: *Process, sig: T.Signal) void {
    @panic("TODO");
}

pub const Id = enum(u16) {
    _,

    pub fn process(pid: Id) *Process {
        return &all.getEntry(pid).?.value;
    }
};
