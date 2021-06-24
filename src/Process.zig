const std = @import("std");

const File = @import("File.zig");
const Memory = @import("Memory.zig");
const T = @import("types.zig");

const Process = @This();
id: Id,
parent_id: Id,
memory: Memory,
fids: std.AutoHashMap(File.Id, void),
status: enum { active, asleep, defunct },

pub var scheduler: Scheduler = undefined;
pub fn active() ?*Process {
    if (scheduler.pending.count == 0) {
        return null;
    } else {
        return scheduler.pending.peekItem(0).process();
    }
}

pub fn fork(self: *Process) !*Process {
    const fids = try self.fids.clone();

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
    }

    const result = try scheduler.createProcess();
    result.parent_id = self.id;
    result.memory = self.memory;
    result.status = self.status;

    result.fids = fids;

    return result;
}

pub fn signal(self: *Process, sig: T.Signal) void {
    @panic("TODO");
}

pub const Id = enum(u16) {
    _,

    fn process(pid: Id) *Process {
        return &scheduler.all.getEntry(pid).?.value;
    }
};

const Scheduler = struct {
    pending: std.fifo.LinearFifo(Id, .Dynamic),
    all: std.AutoHashMap(Id, Process),
    first_available: Id,

    pub fn createProcess(self: *Scheduler) !*Process {
        unreachable;
    }

    pub fn rotate(self: *Scheduler) void {
        const item = scheduler.readItem();
        schedule.writeItem(item) catch unreachable;
    }
};
