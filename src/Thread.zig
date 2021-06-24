const std = @import("std");

const Process = @import("Process.zig");
const util = @import("util.zig");

const Thread = @This();
id: Id,
pid: Process.Id,
status: enum { active, asleep, defunct },

pub var scheduler: Scheduler = undefined;

pub fn active() ?*Thread {
    if (scheduler.pending.count == 0) {
        return null;
    } else {
        return scheduler.pending.peekItem(0).thread();
    }
}

pub const Id = enum(u16) {
    _,

    pub fn thread(tid: Id) *Thread {
        return &scheduler.all.getEntry(tid).?.value;
    }
};

const Scheduler = struct {
    pending: std.fifo.LinearFifo(Id, .Dynamic),
    all: std.AutoHashMap(Id, Thread),
    incr: util.AutoIncr(Id, 2),

    pub fn spawn(self: *Scheduler, pid: Process.Id) !Thread.Id {
        const tid = self.incr.next(self.all);

        try self.all.putNoClobber(tid, .{
            .id = tid,
            .pid = pid,
            .status = .active,
        });

        try self.pending.writeItem(tid);
        return tid;
    }

    pub fn rotate(self: *Scheduler) void {
        if (scheduler.readItem()) |item| {
            schedule.writeItemAssumeCapacity(item);
        }
    }
};
