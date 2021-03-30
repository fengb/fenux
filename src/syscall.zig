const std = @import("std");

const File = @import("File.zig");
const Process = @import("Process.zig");
const T = @import("types.zig");

pub fn handler() callconv(.Naked) noreturn {
    const code = asm volatile (""
        : [ret] "={r0}" (-> u32)
    );
    var raw_args: [6]u32 = undefined;
    raw_args[0] = asm volatile (""
        : [ret] "={r3}" (-> u32)
    );
    raw_args[1] = asm volatile (""
        : [ret] "={r4}" (-> u32)
    );
    raw_args[2] = asm volatile (""
        : [ret] "={r5}" (-> u32)
    );
    raw_args[3] = asm volatile (""
        : [ret] "={r6}" (-> u32)
    );
    raw_args[4] = asm volatile (""
        : [ret] "={r7}" (-> u32)
    );
    raw_args[5] = asm volatile (""
        : [ret] "={r8}" (-> u32)
    );

    if (invoke(process, code, args)) |success| {
        _ = asm volatile ("rfi"
            : [ret] "={r3}" (-> usize)
            : [success] "{r3}" (success),
              [fail] "{cr0}" (false)
        );
    } else |err| {
        _ = asm volatile ("rfi"
            : [ret] "={r12}" (-> usize)
            : [err] "{r3}" (err),
              [fail] "{cr0}" (true)
            : "r3"
        );
    }
}

fn invoke(process: *Process, code: usize, raw_args: [6]usize) !usize {
    inline for (std.meta.declarations(impls)) |decl| {
        if (code == decode(decl.name)) {
            const func = @field(impls, decl.name);
            const Args = std.meta.ArgsTuple(@TypeOf(func));
            var args: Args = undefined;
            if (args.len > 1) {
                inline for (std.meta.fields(Args)[1..]) |field, i| {
                    const Int = std.meta.Int(.unsigned, @bitSizeOf(field.field_type));
                    const raw = try std.math.cast(Int, raw_args[i]);
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
    return error.SyscallNotFound;
}

test {
    _ = invoke;
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
    pub fn @"000 restart"() usize {
        unreachable;
    }

    pub fn @"001 exit"(process: *Process, arg: usize) usize {
        unreachable;
    }

    pub fn @"002 fork"(process: *Process) usize {
        unreachable;
    }

    pub fn @"003 read"(process: *Process, fd: T.Fd, buf: [*]u8, count: usize) !usize {
        const file = try process.file(fd);
        return file.read(buf[0..count]);
    }

    pub fn @"004 write"(process: *Process, fd: T.Fd, buf: [*]u8, count: usize) !usize {
        const file = try process.file(fd);
        return file.write(buf[0..count]);
    }

    pub fn @"005 open"(process: *Process, path: [*:0]const u8, flags: u32, perm: T.Mode) !T.Fd {
        const file = try File.open(std.mem.spanZ(path), flags, perm);
        const fd = file.getFd();
        try process.addFd(fd);
        return fd;
    }

    pub fn @"006 close"(process: *Process, fd: T.Fd) !usize {
        try process.removeFd(fd);
        return 0;
    }
};
