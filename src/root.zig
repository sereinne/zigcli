const std = @import("std");
const getopt = @import("getopt.zig");
const OptionIterator = getopt.OptionIterator;
const Allocator = std.mem.Allocator;
const ArgIterator = std.process.ArgIterator;
const print = std.debug.print;

pub fn CLIBuilder(comptime T: type) type {
    const typeinfo = @typeInfo(T);
    if (typeinfo != .@"struct") {
        const name = @typeName(T);
        @compileError("ERROR: " ++ name ++ " must be a struct");
    }

    return struct {
        const Self = @This();
        inner: T,
        args: OptionIterator,

        pub fn default() Self {
            const dbg_allocator = std.heap.DebugAllocator(.{}){};
            const allocator = dbg_allocator.allocator();
            const argiter = std.process.argsWithAllocator(allocator) catch unreachable;
            return Self{ .inner = undefined, .args = OptionIterator.init(argiter) };
        }

        pub fn init(inner: T, allocator: Allocator) Self {
            const argiter = std.process.argsWithAllocator(allocator) catch unreachable;
            return Self{
                .inner = inner,
                .args = OptionIterator.init(argiter),
            };
        }

        pub fn deinit(self: *Self) void {
            self.args.deinit();
        }

        pub fn parse(self: *Self) void {
            self.args.skip();
            while (self.args.next()) |pair| {
                _ = pair;
            }
        }
    };
}
