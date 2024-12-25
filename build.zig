const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const fuizon = b.addModule("fuizon", .{
        .root_source_file = b.path("src/fuizon.zig"),
        .target = target,
        .optimize = optimize,
    });
    fuizon.link_libc = true;
    fuizon.link_libcpp = true;
    fuizon.linkSystemLibrary("crossterm_ffi", .{ .needed = true });

    const tests = b.addTest(.{
        .name = "test",
        .root_source_file = b.path("src/fuizon.zig"),
        .target = target,
        .optimize = optimize,
    });
    tests.linkLibC();
    tests.linkLibCpp();
    tests.linkSystemLibrary("crossterm_ffi");
    b.installArtifact(tests);
}
