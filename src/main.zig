const std = @import("std");
const zigcli = @import("zigcli");
const subcommands = zigcli.getSubcommands;
const CLIApp = zigcli.CLIApp;
const print = std.debug.print;

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
    defer cli.deinit();
    try cli.parse();
}
