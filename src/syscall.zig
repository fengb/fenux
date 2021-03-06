const std = @import("std");

const File = @import("File.zig");
const Process = @import("Process.zig");
const Thread = @import("Thread.zig");
const P = @import("Memory.zig").P;
const T = @import("types.zig");

pub const handler = switch (std.builtin.arch) {
    .powerpc => handlers.powerpc,
    .x86_64 => handlers.x86_64,
    else => @compileError("handler '" ++ @tagName(std.builtin.arch) ++ "' not defined"),
};

const handlers = struct {
    pub fn powerpc() callconv(.Naked) noreturn {
        const code = asm volatile (""
            : [ret] "={r0}" (-> u32)
        );
        var raw_args: [6]u32 = .{
            asm volatile (""
                : [ret] "={r3}" (-> u32)
            ),
            asm volatile (""
                : [ret] "={r4}" (-> u32)
            ),
            asm volatile (""
                : [ret] "={r5}" (-> u32)
            ),
            asm volatile (""
                : [ret] "={r6}" (-> u32)
            ),
            asm volatile (""
                : [ret] "={r7}" (-> u32)
            ),
            asm volatile (""
                : [ret] "={r8}" (-> u32)
            ),
        };

        var errored = false;

        const thread = Thread.active().?;
        const value = invoke(thread, code, raw_args) catch |err| switch (err) {
            error.IllegalSyscall => {
                thread.pid.process().signal(.ill);
                unreachable;
            },
            else => |e| blk: {
                errored = true;
                break :blk @enumToInt(T.Errno.from(e));
            },
        };
        _ = asm volatile ("rfi"
            : [ret] "={r3}" (-> usize)
            : [value] "{r3}" (value),
              [err] "{cr0}" (errored)
        );
        unreachable;
    }

    pub fn x86_64() callconv(.Naked) noreturn {
        const code = asm volatile (""
            : [ret] "={rax}" (-> u64)
        );
        const ret_addr = asm volatile (""
            : [ret] "={rcx}" (-> u64)
        );
        var raw_args: [6]u64 = .{
            asm volatile (""
                : [ret] "={rdi}" (-> u64)
            ),
            asm volatile (""
                : [ret] "={rsi}" (-> u64)
            ),
            asm volatile (""
                : [ret] "={rdx}" (-> u64)
            ),
            asm volatile (""
                : [ret] "={r10}" (-> u64)
            ),
            asm volatile (""
                : [ret] "={r8}" (-> u64)
            ),
            asm volatile (""
                : [ret] "={r9}" (-> u64)
            ),
        };

        const thread = Thread.active().?;
        const value = invoke(thread, code, raw_args) catch |err| switch (err) {
            error.IllegalSyscall => {
                thread.pid.process().signal(.ill);
                unreachable;
            },
            else => |e| -%@as(u32, @enumToInt(T.Errno.from(e))),
        };
        _ = asm volatile ("sysret"
            : [ret] "={rax}" (-> usize)
            : [value] "{rax}" (value)
        );
        unreachable;
    }
};

const FatalError = error{
    IllegalSyscall,
};

fn invoke(thread: *Thread, code: usize, raw_args: [6]usize) (FatalError || T.Errno.E)!usize {
    inline for (std.meta.declarations(impls)) |decl| {
        if (code == comptime decode(decl.name)) {
            const func = @field(impls, decl.name);
            const Args = std.meta.ArgsTuple(@TypeOf(func));
            var args: Args = undefined;
            args[0] = thread;
            if (args.len > 1) {
                inline for (std.meta.fields(Args)[1..]) |field, i| {
                    const Int = std.meta.Int(.unsigned, @bitSizeOf(field.field_type));
                    const raw = std.math.cast(Int, raw_args[i]) catch |err| switch (err) {
                        error.Overflow => return error.IllegalSyscall,
                    };
                    args[i + 1] = switch (@typeInfo(field.field_type)) {
                        .Enum => @intToEnum(field.field_type, raw),
                        .Pointer => @intToPtr(field.field_type, raw),
                        else => @bitCast(field.field_type, raw),
                    };
                }
            }
            const raw_result = @call(comptime std.builtin.CallOptions{}, func, args);
            const result = switch (@typeInfo(@TypeOf(raw_result))) {
                .ErrorUnion => try raw_result,
                else => raw_result,
            };

            return switch (@typeInfo(@TypeOf(result))) {
                .Enum => @enumToInt(result),
                .Pointer => @ptrToInt(result),
                else => result,
            };
        }
    }
    return error.IllegalSyscall;
}

test {
    _ = invoke;
    _ = handler;
}

fn decode(comptime name: []const u8) comptime_int {
    if (name[0] < '0' or name[0] > '9' or
        name[1] < '0' or name[1] > '9' or
        name[2] < '0' or name[2] > '9' or
        name[3] != ' ')
    {
        @compileError("fn @\"" ++ name ++ "\" must start with '000 '");
    }
    return @as(u16, 100) * (name[0] - '0') + @as(u16, 10) * (name[1] - '0') + (name[2] - '0');
}

test "decode" {
    std.testing.expectEqual(1, decode("001 "));
    std.testing.expectEqual(69, decode("069 "));
    std.testing.expectEqual(420, decode("420 "));
}

const impls = struct {
    pub fn @"000 restart"(thread: *Thread) usize {
        unreachable;
    }

    pub fn @"001 exit"(thread: *Thread, arg: usize) usize {
        unreachable;
    }

    pub fn @"002 fork"(thread: *Thread) !Process.Id {
        const forked = Process.fork(thread) catch |err| switch (err) {
            error.OutOfMemory => return T.Errno.E.ENOMEM,
        };
        return forked.id;
    }

    pub fn @"003 read"(thread: *Thread, fid: File.Id, buf: P(u8), count: usize) !usize {
        const process = thread.pid.process();
        if (!process.fids.contains(fid)) return T.Errno.E.EBADF;
        return fid.file().read(try process.memory.getMany(buf, count));
    }

    pub fn @"004 write"(thread: *Thread, fid: File.Id, buf: P(u8), count: usize) !usize {
        const process = thread.pid.process();
        if (!process.fids.contains(fid)) return T.Errno.E.EBADF;
        return fid.file().write(try process.memory.getMany(buf, count));
    }

    pub fn @"005 open"(thread: *Thread, path: P(u8), flags: File.Flags, perm: File.Mode) !File.Id {
        const process = thread.pid.process();
        const file = try File.open(
            try process.memory.getManyZ(path),
            flags,
            perm,
        );
        errdefer file.release();

        process.fids.putNoClobber(file.id, {}) catch |err| switch (err) {
            error.OutOfMemory => return T.Errno.E.EMFILE,
        };
        return file.id;
    }

    pub fn @"006 close"(thread: *Thread, fid: File.Id) !usize {
        const process = thread.pid.process();
        if (process.fids.remove(fid) == null) {
            return T.Errno.E.EBADF;
        }
        fid.file().release();
        return 0;
    }
};
