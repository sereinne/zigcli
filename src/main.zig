const std = @import("std");
const rootlib = @import("rootlib");
const print = std.debug.print;

const Git = struct {
    help: bool,
    version: bool,
    haha: bool,
    hihi: bool,
    diff: struct {
        pub const docs = true;
        staged: bool,
    },
    branch: struct {
        pub const docs = true;
        delete: bool,
    },
};

pub fn main() !void {
    var cli = rootlib.CreateCLIApp(Git).default();
    defer cli.deinit();
    print("help before: {}\n", .{cli.template.help});
    print("version before: {}\n", .{cli.template.version});
    print("haha before: {}\n", .{cli.template.haha});
    print("hihi before: {}\n", .{cli.template.hihi});
    print("diff.staged before: {}\n", .{cli.template.diff.staged});
    print("scoped: {s}\n", .{cli.scope});
    try cli.parse();
    print("help after: {}\n", .{cli.template.help});
    print("version after: {}\n", .{cli.template.version});
    print("haha after: {}\n", .{cli.template.haha});
    print("hihi after: {}\n", .{cli.template.hihi});
    print("diff.staged before: {}\n", .{cli.template.diff.staged});
    print("scoped: {s}\n", .{cli.scope});
}
