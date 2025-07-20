const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zigcli_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/root.zig"),
    });

    const exe_mod = b.createModule(.{ .target = target, .optimize = optimize, .root_source_file = b.path("src/main.zig") });
    exe_mod.addImport("zigcli", zigcli_mod);

    const root_exe = b.addExecutable(.{
        .name = "main",
        .root_module = exe_mod,
    });

    b.installArtifact(root_exe);

    const run_root_exe = b.addRunArtifact(root_exe);
    run_root_exe.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_root_exe.addArgs(args);
    }

    const run_exe = b.step("r", "run main executable");
    run_exe.dependOn(&run_root_exe.step);
}
