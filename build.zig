const std = @import("std");
const Builder = std.build.Builder;

const wii_target = std.zig.CrossTarget{
    .cpu_arch = .powerpc,
    .os_tag = .freestanding,
    .abi = .eabi,
    .cpu_model = .{ .explicit = &std.Target.powerpc.cpu.ppc750 },
    .cpu_features_add = std.Target.powerpc.featureSet(&.{.hard_float}),
};

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const obj = b.addObject("main", "src/main.zig");
    obj.setOutputDir("build");
    obj.linkLibC();
    obj.setLibCFile("libc.txt");
    obj.addIncludeDir("devkitpro/libogc/include");
    obj.setBuildMode(mode);
    obj.setTarget(wii_target);

    const make = b.addSystemCommand(&[_][]const u8{ "docker-compose", "run", "devkitpro", "make" });
    b.default_step.dependOn(&obj.step);
    b.default_step.dependOn(&make.step);

    const host_tests = b.addTest("src/main.zig");
    host_tests.setBuildMode(mode);

    const wii_tests = b.addTest("src/main.zig");
    wii_tests.setBuildMode(mode);
    var wii_test_target = wii_target;
    wii_test_target.os_tag = .linux;
    wii_test_target.abi = .musleabi;
    wii_tests.setTarget(wii_test_target);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&host_tests.step);
    test_step.dependOn(&wii_tests.step);

    const test_host_step = b.step("test:host", "Run library tests -- host only");
    test_host_step.dependOn(&host_tests.step);

    const test_wii_step = b.step("test:wii", "Run library tests -- Wii only");
    test_wii_step.dependOn(&wii_tests.step);
}
