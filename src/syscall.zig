const std = @import("std");

const File = @import("file.zig").File;
const Mode = @import("file.zig").Mode;
const Process = @import("Process.zig");
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

        if (invoke(Process.active.?, code, raw_args)) |value| {
            const is_error = value > -4096 and value < 0;
            _ = asm volatile ("rfi"
                : [ret] "={r3}" (-> usize)
                : [value] "{r3}" (value),
                  [err] "{cr0}" (is_error)
            );
            unreachable;
        } else |err| {
            Process.active.?.signal(.ill);
            unreachable;
        }
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

        if (invoke(Process.active.?, code, raw_args)) |value| {
            _ = asm volatile ("sysret"
                : [ret] "={rax}" (-> usize)
                : [value] "{rax}" (value)
            );
            unreachable;
        } else |err| {
            Process.active.?.signal(.ill);
            unreachable;
        }
    }
};

const FatalError = error{
    IllegalSyscall,
};

fn invoke(process: *Process, code: usize, raw_args: [6]usize) FatalError!isize {
    const value = invokeRaw(process, code, raw_args) catch |err| switch (err) {
        error.IllegalSyscall => |e| return e,
        else => |e| {
            // TODO: change this once we can switch off error sets
            const errno = T.Errno.from(e);
            return -@as(isize, @enumToInt(errno));
        },
    };
    return @bitCast(isize, value);
}

fn invokeRaw(process: *Process, code: usize, raw_args: [6]usize) (FatalError || T.Errno.E)!usize {
    inline for (std.meta.declarations(impls)) |decl| {
        if (code == decode(decl.name)) {
            const func = @field(impls, decl.name);
            const Args = std.meta.ArgsTuple(@TypeOf(func));
            var args: Args = undefined;
            args[0] = process;
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

fn decode(comptime name: []const u8) u16 {
    if (name[0] < '0' or name[0] > '9' or
        name[1] < '0' or name[1] > '9' or
        name[2] < '0' or name[2] > '9' or
        name[3] != ' ')
    {
        @compileError("fn @\"" ++ name ++ "\" must start with '000 '");
    }
    return 100 * (name[0] - '0') + 100 * (name[1] - '0') * 10 + (name[2] - '0');
}

const impls = struct {
    pub fn @"000 restart"(process: *Process) usize {
        unreachable;
    }

    pub fn @"001 exit"(process: *Process, arg: usize) usize {
        unreachable;
    }

    pub fn @"002 fork"(process: *Process) usize {
        unreachable;
    }

    pub fn @"003 read"(process: *Process, file: File, buf: [*]u8, count: usize) !usize {
        if (!process.files.contains(file)) return T.Errno.E.EBADF;
        return file.read(buf[0..count]);
    }

    pub fn @"004 write"(process: *Process, file: File, buf: [*]u8, count: usize) !usize {
        if (!process.files.contains(file)) return T.Errno.E.EBADF;
        return file.write(buf[0..count]);
    }

    pub fn @"005 open"(process: *Process, path: [*:0]const u8, flags: u32, perm: Mode) !File {
        const file = try File.open(std.mem.spanZ(path), flags, perm);
        errdefer file.close();

        process.files.putNoClobber(file, {}) catch |err| switch (err) {
            error.OutOfMemory => return T.Errno.E.EMFILE,
        };
        return file;
    }

    pub fn @"006 close"(process: *Process, file: File) !usize {
        if (process.files.remove(file) == null) {
            return T.Errno.E.EBADF;
        }
        return 0;
    }
};
