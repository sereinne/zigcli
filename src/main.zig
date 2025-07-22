// module imports
const std = @import("std");
const zigcli = @import("zigcli");
const Struct = std.builtin.Type.Struct;
// struct imports
const CLIBuilder = zigcli.CLIBuilder;
const Config = zigcli.Config;
const parseWithFallback = zigcli.parserWithFallback;
// function imports
const print = std.debug.print;

const Git = struct { pager: bool, commit: struct { message: []const u8 }, stash: struct {
    hash: u32,
} };

fn modifyField(blueprint: anytype, name: []const u8, value: []const u8) !void {
    const info = @typeInfo(@TypeOf(blueprint));
    if (info != .@"struct") {
        @compileError("not a struct");
    }

    const struct_info = info.@"struct";

    const fields = struct_info.fields;
    inline for (fields) |field| {
        const inner = @typeInfo(field.type);
        if (inner == .@"struct") {
            modifyField(@field(blueprint, field.name), name, value);
        } else {
            if (std.mem.eql(u8, field.name, name)) {
                @field(blueprint, field.name) = try parseWithFallback(field.type, Git, value, null);
            }
        }
    }
}

pub fn main() !void {
    var g = Git{ .pager = true, .commit = .{ .message = "hello" }, .stash = .{ .hash = 1 } };
    @compileLog(@typeInfo(@TypeOf(&g)));
}
