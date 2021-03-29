const File = @This();

ref_count: u16 = 0,

var all = [_]File{.{ .ref_count = 0xAAAA }} ** 3 ++
    [_]File{.{ .ref_count = 0 }} ** 65536 - 3;

pub var first_available: fd_t = 3;

pub fn get(fd: fd_t) *File {
    return &all[@enumToInt(fd)];
}

fn fd(self: *File) fd_t {
    return (@ptrToInt(self) - @ptrToInt(&all)) / @sizeOf(File);
}

pub fn open(path: []const u8, flags: u32, perm: mode_t) !*File {
    var scan = @enumToInt(first_available);
    while (all[scan].ref_count != 0) : (scan += 1) {}
    first_available = @intToEnum(fd_t, scan);
}

pub fn close(file: *File) void {
    const fd = file.fd();
    switch (fd) {
        .stdin, .stdout, .stderr => return,
        else => {},
    }
    file.refs -= 1;
    if (file.refs == 0) {
        file.deinit();
        if (@enumToInt(fd) < @enumToInt(first_available)) {
            available = fd;
        }
    }
}
