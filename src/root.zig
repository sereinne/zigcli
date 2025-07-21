// module imports
const std = @import("std");
const getopt = @import("getopt.zig");
const parser = @import("parser.zig");
// struct imports
const OptionIterator = getopt.OptionIterator;
const Allocator = std.mem.Allocator;
const ArgIterator = std.process.ArgIterator;
// function imports
const print = std.debug.print;
const eql = std.mem.eql;
const parserWithFallback = parser.parseWithFallback;
// type alias
const Parser = parser.Parser;

pub fn Config(comptime T: type) type {
    return struct {
        custom_parser: ?Parser(T),
    };
}

pub fn CLIBuilder(comptime T: type, comptime U: type, comptime config: Config(U)) type {
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

        pub fn parse(self: *Self) !void {
            self.args.skip();
            while (self.args.next()) |pair| {
                const info = @typeInfo(@TypeOf(self.inner));
                // it is guaranteed to be a `struct`
                const struct_fields = info.@"struct".fields;
                const stripped = pair.name[2..];
                inline for (struct_fields) |field| {
                    if (eql(u8, field.name, stripped) and field.type == bool) {
                        @field(self.inner, field.name) = !@field(self.inner, field.name);
                    } else if (eql(u8, field.name, stripped)) {
                        @field(self.inner, field.name) = try parserWithFallback(field.type, U, pair.value.?, config.custom_parser);
                    }
                }
            }
        }
    };
}
