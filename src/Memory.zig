const std = @import("std");

const Memory = @This();

pub fn get(memory: *Memory, ptr: anytype) !@TypeOf(ptr).Pointee {
    @panic("TODO");
}

pub fn getMany(memory: *Memory, ptr: anytype, len: usize) ![]@TypeOf(ptr).Pointee {
    @panic("TODO");
}

pub fn getManyZ(memory: *Memory, ptr: anytype) ![]@TypeOf(ptr).Pointee {
    @panic("TODO");
}

pub fn set(memory: *Memory, ptr: anytype, value: @TypeOf(ptr).Pointee) !void {
    @panic("TODO");
}

pub fn P(comptime T: type) type {
    return enum(u32) {
        _,

        const Self = @This();
        const Pointee = T;

        pub fn init(addr: u32) Self {
            return @intToEnum(Self, addr);
        }
    };
}
