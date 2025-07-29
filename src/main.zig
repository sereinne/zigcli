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
    args: std.ArrayList([]const u8),
    diff: struct {
        staged: bool,
        args: std.ArrayList([]const u8),
    },
};

fn isValidArgsField(comptime T: type) bool {
    const typeinfo = @typeInfo(T);
    if (typeinfo != .@"struct") {
        const type_name = @typeName(T);
        @compileError("ERROR: type " ++ type_name ++ " must be a struct");
    }

    var result = true;
    const fields = typeinfo.@"struct".fields;
    inline for (fields) |field| {
        const field_info = @typeInfo(field.type);
        if (field_info == .@"struct") {
            result = isValidArgsField(field.type);
        } else if (eql(u8, field.name, "args") and field.type != std.ArrayList([]const u8)) {
            result = false;
        }
    }

    return result;
}

pub fn main() !void {
    var dbg = std.heap.DebugAllocator(.{}){};
    const allocator = dbg.allocator();
    var cli = CLIApp(Demo).init(allocator);
    //print("before: \n", .{});
    //print("pager {}\n", .{cli.inner.pager});
    //print("status {}\n", .{cli.inner.status});
    //print("bar {}\n", .{cli.inner.bar});
    //print("main command arg: {s}\n", .{cli.inner.args.items[0]});
    //print("diff.staged {}\n", .{cli.inner.diff.staged});
    try cli.parse();
    //print("\nafter: \n", .{});
    //print("pager {}\n", .{cli.inner.pager});
    //print("status {}\n", .{cli.inner.status});
    //print("bar {}\n", .{cli.inner.bar});
    //print("main command arg {s}\n", .{cli.inner.args.items[0]});
    //print("diff.staged {}\n", .{cli.inner.diff.staged});

}
