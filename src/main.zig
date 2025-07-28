const std = @import("std");
const zigcli = @import("zigcli");
const ArrayListAligned = std.ArrayListAligned;
const subcommands = zigcli.getSubcommands;
const CLIApp = zigcli.CLIApp;
const print = std.debug.print;
const eql = std.mem.eql;
const parseWithFallback = zigcli.parseWithFallback;

const Demo = struct {
    pager: bool,
    status: bool,
    bar: bool,
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
    print("before: \n", .{});
    print("pager {}\n", .{cli.inner.pager});
    print("status {}\n", .{cli.inner.status});
    print("bar {}\n", .{cli.inner.bar});
    print("main command arg: {s}\n", .{cli.inner.arg});
    print("diff.staged {}\n", .{cli.inner.diff.staged});
    try cli.parse();
    print("\nafter: \n", .{});
    print("pager {}\n", .{cli.inner.pager});
    print("status {}\n", .{cli.inner.status});
    print("bar {}\n", .{cli.inner.bar});
    print("main command arg {s}\n", .{cli.inner.arg});
    print("diff.staged {}\n", .{cli.inner.diff.staged});
}
