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

    const static_lib = b.addStaticLibrary(.{
        .name = "zigcli",
        .root_module = root_lib,
    });

    const build_lib = b.step("b", "build static library");

    build_lib.dependOn(&static_lib.step);
}
