const std = @import("std");

const Process = @import("Process.zig");

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

    inline for (std.meta.declarations(impls)) |decl| {
        if (code == decode(decl.name)) {
            const func = @field(impls, decl.name);
            const Args = std.meta.ArgsTuple(@TypeOf(func));
            var args: Args = undefined;
            inline for (std.meta.fields(Args)[1..]) |field, i| {
                const raw_arg = raw[i];
                args[i + 1] = switch (@typeInfo(field.field_type)) {
                    .Enum => @intToEnum(field.field_type, raw),
                    .Pointer => @intToPtr(field.field_type, raw),
                    else => @bitCast(field.field_type, raw),
                };
            }

            if (@call(.{}, func, args)) |success| {
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
            unreachable;
        }
    }
}

fn decode(name: []const u8) void {
    if (name[0] < '0' or name[0] > '9' or
        name[1] < '0' or name[1] > '9' or
        name[2] < '0' or name[2] > '9' or
        name[3] != ' ')
    {
        @compileError("fn @\"" ++ name ++ "\" must start with '000 '");
    }
    return 100 * (decl.name[0] - '0') + 100 * (decl.name[1] - '0') * 10 + (decl.name[2] - '0');
}

const impls = struct {
    pub fn @"000 restart"() usize {
        unreachable;
    }

    pub fn @"001 exit"(process: *Process, arg: usize) void {
        unreachable;
    }

    pub fn @"002 fork"(process: *Process) usize {
        unreachable;
    }

    pub fn @"003 read"(process: *Process, fd: fd_t, buf: [*]u8, count: usize) !usize {
        const file = try process.file(fd);
        return file.read(buf[0..count]);
    }

    pub fn @"004 write"(process: *Process, fd: fd_t, buf: [*]u8, count: usize) !usize {
        const file = try process.file(fd);
        return file.write(buf[0..count]);
    }

    pub fn @"005 open"(process: *Process, path: [*:0]const u8, flags: u32, perm: mode_t) !fd_t {
        const fd = File.open(std.mem.spanZ(path), flags, perm);
        try process.addFd(fd);
        return fd;
    }

    pub fn @"006 close"(process: *Process, fd: fd_t) !usize {
        const file = try process.file(fd);
        try process.removeFd(fd);
        return 0;
    }
};
