// module imports
const std = @import("std");
const zigcli = @import("zigcli");
// struct imports
const CLIBuilder = zigcli.CLIBuilder;
const Config = zigcli.Config;
// function imports
const print = std.debug.print;

const Echo = struct {
    t: NotEmpty,
};

const NotEmpty = struct { s: []const u8 };

fn notEmptyParser(item: []const u8) !NotEmpty {
    if (std.mem.eql(u8, item, "")) {
        return error.EmptyString;
    }
    return NotEmpty{ .s = item };
}

pub fn main() !void {
    const app = Echo{ .t = NotEmpty{ .s = "h" } };
    var dbg_alloc = std.heap.DebugAllocator(.{}){};
    const allocator = dbg_alloc.allocator();
    var cli = CLIBuilder(Echo, NotEmpty, .{ .custom_parser = notEmptyParser }).init(app, allocator);
    print("before parsing: ", .{});
    print("{any}\n", .{cli.inner.t});
    try cli.parse();
    print("after parsing: ", .{});
    print("{any}\n", .{cli.inner.t});
    defer cli.deinit();
}
