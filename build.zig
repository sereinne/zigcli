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
}
