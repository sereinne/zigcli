const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zigcli_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/root.zig"),
    });

    const argparser_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/argparser.zig"),
    });

    const valueparser_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/value_parser.zig"),
    });

    const test_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("tests/unit_test.zig"),
    });

    test_mod.addImport("argparser", argparser_mod);

    const exe_mod = b.createModule(.{ .target = target, .optimize = optimize, .root_source_file = b.path("src/main.zig") });
    exe_mod.addImport("zigcli", zigcli_mod);
    exe_mod.addImport("argparser", argparser_mod);
    exe_mod.addImport("value_parser", valueparser_mod);

    const root_exe = b.addExecutable(.{
        .name = "main",
        .root_module = exe_mod,
    });

    const add_test = b.addTest(.{
        .name = "unit_tests",
        .root_module = test_mod,
    });

    b.installArtifact(root_exe);

    const run_root_exe = b.addRunArtifact(root_exe);
    const run_test_exe = b.addRunArtifact(add_test);
    run_root_exe.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_root_exe.addArgs(args);
    }

    const run_exe = b.step("r", "run main executable");
    const run_test = b.step("t", "tests suite");
    run_exe.dependOn(&run_root_exe.step);
    run_test.dependOn(&run_test_exe.step);
}
