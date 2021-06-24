const std = @import("std");

pub fn AutoIncr(comptime E: type, comptime min: comptime_int) type {
    return struct {
        const Self = @This();

        prev: E = @intToEnum(E, min),

        pub fn next(self: *Self, container: anytype) E {
            var scan = @enumToInt(self.prev);
            while (container.contains(@intToEnum(E, scan))) {
                if (@addWithOverflow(@TypeOf(scan), scan, 1, &scan)) {
                    scan = min;
                }
                if (scan == @enumToInt(self.prev)) {
                    @panic("FIXME: Cannot increment");
                }
            }

            self.prev = @intToEnum(E, scan);
            return self.prev;
        }

        pub fn reset(self: *Self, value: E) void {
            std.debug.assert(@enumToInt(value) >= min);
            self.prev = value;
        }
    };
}

test "AutoIncr" {
    const E = enum(u8) { _ };
    var incr: AutoIncr(E, 2) = .{};
    var container = std.AutoHashMap(E, void).init(std.testing.allocator);
    defer container.deinit();

    std.testing.expectEqual(@intToEnum(E, 2), incr.next(container));
    std.testing.expectEqual(@intToEnum(E, 2), incr.next(container));
    std.testing.expectEqual(@intToEnum(E, 2), incr.next(container));

    try container.put(@intToEnum(E, 2), {});
    std.testing.expectEqual(@intToEnum(E, 3), incr.next(container));
    std.testing.expectEqual(@intToEnum(E, 3), incr.next(container));

    container.clearRetainingCapacity();
    incr.reset(@intToEnum(E, 255));
    try container.put(@intToEnum(E, 255), {});
    std.testing.expectEqual(@intToEnum(E, 2), incr.next(container));
}
