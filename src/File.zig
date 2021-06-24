const std = @import("std");

const File = @This();
id: Id = undefined,
ref_count: u16 = 0,

var all: std.AutoHashMap(File.Id, File) = undefined;
var first_available: File.Id = @intToEnum(File.Id, 3);

pub fn open(path: []const u8, flags: Flags, perm: Mode) !*File {
    var scan = @enumToInt(first_available);
    while (!all.contains(@intToEnum(Id, scan))) : (scan += 1) {}

    const fid = @intToEnum(File.Id, scan);
    if (true) {
        unreachable;
    }
    const file = fid.file();
    file.id = fid;
    file.ref_count = 1;
    first_available = fid;
    return file;
}

pub fn close(file: *File) void {
    switch (file.id) {
        .stdin, .stdout, .stderr => return,
        else => {},
    }
    file.ref_count -= 1;
    if (file.ref_count == 0) {
        file.deinit();
        if (@enumToInt(file.id) < @enumToInt(first_available)) {
            first_available = file.id;
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

pub const Id = enum(u32) {
    stdin = 0,
    stdout = 1,
    stderr = 2,
    _,

    pub fn file(fid: Id) *File {
        return &all.getEntry(fid).?.value;
    }
};

pub const Flags = EndianOrdered(packed struct {
    access: u3,
    _pad1: u3,

    creat: bool,
    excl: bool,
    noctty: bool,

    trunc: bool,
    append: bool,
    nonblock: bool,

    dsync: bool,
    @"async": bool,
    directory: bool,

    nofollow: bool,
    largefile: bool,
    direct: bool,

    noatime: bool,
    cloexec: bool,
    sync: bool, // sync + dsync == O_SYNC

    path: bool,
    tmpfile: bool, // tmpfile + directory == O_TMPFILE
    _pad2: u1,

    _pad3: u8,
});

pub const Access = enum(u2) {
    read = 0o0,
    write = 0o1,
    read_write = 0o2,
    _,

    pub fn raw(self: Format) u4 {
        return @enumToInt(self);
    }
};

test "Flags" {
    std.testing.expectEqual(@as(usize, 4), @sizeOf(Flags));
    std.testing.expectEqual(@as(usize, 32), @bitSizeOf(Flags));
}

pub const Mode = EndianOrdered(packed struct {
    other_execute: bool,
    other_write: bool,
    other_read: bool,

    group_execute: bool,
    group_write: bool,
    group_read: bool,

    owner_execute: bool,
    owner_write: bool,
    owner_read: bool,

    restricted_delete: bool,
    set_gid: bool,
    set_uid: bool,

    // TODO: make this type Format, compiler currently crashes with "buf_read_value_bytes enum packed"
    format: u4,

    _pad: u16 = 0,
});

pub const Format = enum(u4) {
    fifo = 0o1,
    char = 0o2,
    dir = 0o4,
    block = 0o6,
    reg = 0o10,
    symlink = 0o12,
    socket = 0o14,
    _,

    pub fn raw(self: Format) u4 {
        return @enumToInt(self);
    }
};

test "Mode" {
    std.testing.expectEqual(@as(usize, 4), @sizeOf(Mode));
    std.testing.expectEqual(@as(usize, 32), @bitSizeOf(Mode));

    const S_IFMT: u32 = 0o170000;

    const S_IFDIR: u32 = 0o040000;
    const S_IFCHR: u32 = 0o020000;
    const S_IFBLK: u32 = 0o060000;
    const S_IFREG: u32 = 0o100000;
    const S_IFIFO: u32 = 0o010000;
    const S_IFLNK: u32 = 0o120000;
    const S_IFSOCK: u32 = 0o140000;

    var mode = @bitCast(Mode, @as(u32, 0));
    mode.format = Format.fifo.raw();
    std.testing.expectEqual(S_IFIFO, S_IFMT & @bitCast(u32, mode));
    mode.format = Format.block.raw();
    std.testing.expectEqual(S_IFBLK, S_IFMT & @bitCast(u32, mode));

    const S_ISUID: u32 = 0o4000;
    const S_ISGID: u32 = 0o2000;
    const S_ISVTX: u32 = 0o1000;

    std.testing.expectEqual(@as(u32, 0), S_ISVTX & @bitCast(u32, mode));
    mode.restricted_delete = true;
    std.testing.expectEqual(S_ISVTX, S_ISVTX & @bitCast(u32, mode));

    std.testing.expectEqual(@as(u32, 0), S_ISUID & @bitCast(u32, mode));
    mode.set_uid = true;
    std.testing.expectEqual(S_ISUID, S_ISUID & @bitCast(u32, mode));

    const S_IRUSR: u32 = 0o400;
    const S_IWUSR: u32 = 0o200;
    const S_IXUSR: u32 = 0o100;
    const S_IRGRP: u32 = 0o040;
    const S_IWGRP: u32 = 0o020;
    const S_IXGRP: u32 = 0o010;
    const S_IROTH: u32 = 0o004;
    const S_IWOTH: u32 = 0o002;
    const S_IXOTH: u32 = 0o001;
}

fn EndianOrdered(comptime T: type) type {
    if (std.builtin.endian == .Little) {
        return T;
    } else {
        var info = @typeInfo(T);
        const len = info.Struct.fields.len;
        var reversed_fields: [len]std.builtin.TypeInfo.StructField = undefined;
        for (info.Struct.fields) |field, i| {
            reversed_fields[len - 1 - i] = field;
        }
        info.Struct.fields = &reversed_fields;
        return @Type(info);
    }
}
