const std = @import("std");

const File = @import("File.zig");
const T = @import("types.zig");

const Process = @This();
id: Id,
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

pub fn signal(self: *Process, sig: T.Signal) void {
    @panic("FIXME");
}

const Id = enum(u16) {
    _,

    fn process(pid: Id) *Process {
        return &scheduler.all.getEntry(pid).?.value;
    }
};

const Scheduler = struct {
    pending: std.fifo.LinearFifo(Id, .Dynamic),
    all: std.AutoHashMap(Id, Process),

    pub fn rotate(scheduler: *Scheduler) void {
        const item = scheduler.readItem();
        schedule.writeItem(item) catch unreachable;
    }
};
