const T = @import("types.zig");

pub const File = enum(u32) {
    stdin = 0,
    stdout = 1,
    stderr = 2,
    _,

    var first_available: File = @intToEnum(File, 3);

    pub fn open(path: []const u8, flags: u32, perm: T.Mode) !File {
        var scan = @enumToInt(first_available);
        while (Data.all[scan].ref_count != 0) : (scan += 1) {}

        const file = @intToEnum(File, scan);
        if (true) {
            unreachable;
        }
        file.data().ref_count += 1;
        first_available = file;
        return file;
    }

    pub fn close(file: File) void {
        switch (file) {
            .stdin, .stdout, .stderr => return,
            else => {},
        }
        const d = file.data();
        d.ref_count -= 1;
        if (d.ref_count == 0) {
            file.deinit();
            if (@enumToInt(file) < @enumToInt(first_available)) {
                first_available = file;
            }
        }
    }

    pub fn read(file: File, buf: []u8) !usize {
        return 0;
    }

    pub fn write(file: File, bytes: []const u8) !usize {
        return 0;
    }

    fn deinit(file: File) void {
        @panic("TODO");
    }

    fn data(file: File) *Data {
        return &Data.all[@enumToInt(file)];
    }
};

const Data = struct {
    ref_count: u16 = 0,

    var all = [_]Data{.{ .ref_count = 0xAAAA }} ** 3 ++
        [_]Data{.{ .ref_count = 0 }} ** (65536 - 3);
};
