const std = @import("std");

const File = @import("File.zig");
const Memory = @import("Memory.zig");
const T = @import("types.zig");
const util = @import("util.zig");

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

    return try scheduler.createProcess(.{
        .id = undefined,
        .parent_id = self.id,
        .memory = self.memory,
        .status = self.status,
        .fids = fids,
    });
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
    incr: util.AutoIncr(Id, 2),

    pub fn createProcess(self: *Scheduler, data: Process) !*Process {
        const pid = self.incr.next(self.all);
        var copy = data;
        copy.id = pid;
        try self.all.putNoClobber(pid, data);

        if (data.status == .active) {
            try self.pending.writeItem(pid);
        }
        return pid.process();
    }

    pub fn rotate(self: *Scheduler) void {
        if (scheduler.readItem()) |item| {
            schedule.writeItemAssumeCapacity(item);
        }
    }
};
