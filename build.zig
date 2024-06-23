const std = @import("std");

pub fn build(b: *std.Build) void {
    // Common stuff
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Declare library
    const lib = b.addStaticLibrary(.{
        .name = "mrg32k3a",
        .root_source_file = b.path("src/mrg32k3a.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(lib);

    // Declare unit tests
    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/mrg32k3a.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    b.installArtifact(lib_unit_tests);

    // Deal with C
    lib_unit_tests.addIncludePath(b.path("src"));
    lib_unit_tests.addCSourceFile(.{ .file = b.path("src/reference.c") });
    lib_unit_tests.linkLibC();
}
