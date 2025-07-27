const std = @import("std");
const zigcli = @import("zigcli");
const subcommands = zigcli.getSubcommands;
const CLIApp = zigcli.CLIApp;
const print = std.debug.print;
const eql = std.mem.eql;
const parseWithFallback = zigcli.parseWithFallback;

const Demo = struct {
    pager: bool,
    status: bool,
    arg: []const u8,
    diff: struct {
        staged: bool,
        arg: []const u8,
    },
};

pub fn main() !void {
    var dbg = std.heap.DebugAllocator(.{}){};
    const allocator = dbg.allocator();
    var cli = CLIApp(Demo).init(allocator);
    print("pager {}\n", .{cli.inner.pager});
    print("status {}\n", .{cli.inner.status});
    print("diff.staged {}\n", .{cli.inner.diff.staged});
    print("main command arg: {s}\n", .{cli.inner.arg});
    try cli.parse();
    print("pager {}\n", .{cli.inner.pager});
    print("status {}\n", .{cli.inner.status});
    print("diff.staged {}\n", .{cli.inner.diff.staged});
    print("subcommands arg {s}\n", .{cli.inner.diff.arg});
}
