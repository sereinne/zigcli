const std = @import("std");
const zigcli = @import("zigcli");
const subcommands = zigcli.getSubcommands;
const CLIApp = zigcli.CLIApp;
const print = std.debug.print;
const eql = std.mem.eql;
const parseWithFallback = zigcli.parseWithFallback;

const Demo = struct {
    pager: bool,
    diff: struct {
        staged: bool,
    },
};

pub fn main() !void {
    var dbg = std.heap.DebugAllocator(.{}){};
    const allocator = dbg.allocator();
    var cli = CLIApp(Demo).init(allocator);
    print("{}\n", .{cli.inner.pager});
    print("{}\n", .{cli.inner.diff.staged});
    try cli.parse();
    print("{}\n", .{cli.inner.pager});
    print("{}\n", .{cli.inner.diff.staged});
}
