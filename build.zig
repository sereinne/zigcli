const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const root_module = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const root_lib = b.addStaticLibrary(.{
        .name = "zigcli",
        .root_module = root_module,
    });

    b.installArtifact(root_lib);

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_mod.addImport("zigcli", root_module);

    const exe = b.addExecutable(.{
        .name = "demo",
        .root_module = exe_mod,
    });

    const exe_run = b.addRunArtifact(exe);

    if (b.args) |args| {
        exe_run.addArgs(args);
    }

    const run = b.step("r", "run exe");

    run.dependOn(&exe_run.step);
}
