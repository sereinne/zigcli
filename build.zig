const std = @import("std");

pub fn build(b: *std.Build) void {
    // default `target` and `optimize`
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const root_lib = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const root_exe = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const root_test = b.createModule(.{
        .root_source_file = b.path("tests/unit_test.zig"),
        .target = target,
        .optimize = optimize,
    });

    root_exe.addImport("rootlib", root_lib);
    root_test.addImport("rootlib", root_lib);

    const exe = b.addExecutable(.{
        .name = "main",
        .root_module = root_exe,
    });

    const test_runner = b.addTest(.{
        .name = "Unit tests",
        .root_module = root_test,
    });

    const static_lib = b.addStaticLibrary(.{
        .name = "zigcli",
        .root_module = root_lib,
    });

    const run_exe = b.addRunArtifact(exe);

    if (b.args) |args| {
        run_exe.addArgs(args);
    }

    const run_unit_tests = b.addRunArtifact(test_runner);

    const run_exe_step = b.step("r", "run main.zig");
    const run_test_step = b.step("t", "run tests/unit_test.zig");
    const build_lib = b.step("b", "build static library");

    run_exe_step.dependOn(&run_exe.step);
    run_test_step.dependOn(&run_unit_tests.step);
    build_lib.dependOn(&static_lib.step);
}
