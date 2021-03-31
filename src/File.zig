const T = @import("types.zig");

const File = @This();

ref_count: u16 = 0,

var all = [_]File{.{ .ref_count = 0xAAAA }} ** 3 ++
    [_]File{.{ .ref_count = 0 }} ** (65536 - 3);

pub var first_available: T.Fd = @intToEnum(T.Fd, 3);

pub fn get(fd: T.Fd) *File {
    return &all[@enumToInt(fd)];
}

pub fn getFd(self: *File) T.Fd {
    const raw = @ptrToInt(self) - @ptrToInt(&all) / @sizeOf(File);
    return @intToEnum(T.Fd, @intCast(u32, raw));
}

pub fn open(path: []const u8, flags: u32, perm: T.Mode) !*File {
    var scan = @enumToInt(first_available);
    while (all[scan].ref_count != 0) : (scan += 1) {}

    const fd = @intToEnum(T.Fd, scan);
    const file = get(fd);
    if (true) {
        unreachable;
    }
    file.ref_count += 1;
    first_available = fd;
    return file;
}

fn deinit(file: *File) void {
    @panic("TODO");
}

pub fn close(file: *File) void {
    const fd = file.getFd();
    switch (fd) {
        .stdin, .stdout, .stderr => return,
        else => {},
    }
    file.ref_count -= 1;
    if (file.ref_count == 0) {
        file.deinit();
        if (@enumToInt(fd) < @enumToInt(first_available)) {
            first_available = fd;
        }
    }
}

pub fn read(file: *File, buf: []u8) !usize {
    return 0;
}

pub fn write(file: *File, data: []const u8) !usize {
    return 0;
}
