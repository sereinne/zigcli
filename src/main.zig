const std = @import("std");
const zigcli = @import("zigcli");
const print = std.debug.print;
const CLIBuilder = zigcli.CLIBuilder;

const App = struct {
    foo: []const u8,
    bar: []const u8,
    baz: []const u8,
};

pub fn main() void {
    var dbg_allocator = std.heap.DebugAllocator(.{}){};
    const allocator = dbg_allocator.allocator();

    const app = App{ .foo = "foo", .bar = "bar", .baz = "baz" };

    var cli = CLIBuilder(App).init(app, allocator);
    defer cli.deinit();
    cli.parse();
}
