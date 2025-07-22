// module imports
const std = @import("std");
const getopt = @import("getopt.zig");
const parser = @import("parser.zig");
// struct imports
const OptionIterator = getopt.OptionIterator;
const Allocator = std.mem.Allocator;
const ArgIterator = std.process.ArgIterator;
const Type = std.builtin.Type;
const Struct = Type.Struct;
// function imports
const print = std.debug.print;
const eql = std.mem.eql;
pub const parserWithFallback = parser.parseWithFallback;
// type alias
const Parser = parser.Parser;

pub fn Config(comptime T: type) type {
    return struct {
        custom_parser: ?Parser(T),
    };
}

fn isStruct(blueprint: Type) bool {
    return blueprint == .@"struct";
}

pub fn CLIBuilder(comptime T: type, comptime U: type, comptime config: Config(U)) type {
    const typeinfo = @typeInfo(T);

    if (isStruct(typeinfo)) {
        const name = @typeName(T);
        @compileError("ERROR: " ++ name ++ " must be a struct");
    }

    const struct_info = typeinfo.@"struct";
    const fields = struct_info.fields;

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

        pub fn init(inner: *T, allocator: Allocator) Self {
            const argiter = std.process.argsWithAllocator(allocator) catch unreachable;
            return Self{
                .inner = inner,
                .args = OptionIterator.init(argiter),
            };
        }

        fn invertFieldValue(self: *Self, stripped_flag: []const u8) !void {
            inline for (fields) |field| {
                if (eql(u8, field.name, stripped_flag) and field.type != bool) {
                    return error.MatchedButNotABoolean;
                }
                @field(self.inner, field.name) = !@field(self.inner, field.name);
            }
        }

        fn modifyFieldValue(self: *Self, comptime Fallback: type, stripped_flag: []const u8, cli_value: []const u8, fallback_parser: ?Parser(Fallback)) !void {
            inline for (fields) |field| {
                if (eql(u8, field.name, stripped_flag)) {
                    @field(self.inner, field.name) = try parserWithFallback(field.type, Fallback, cli_value, fallback_parser);
                }
            }
        }

        pub fn deinit(self: *Self) void {
            self.args.deinit();
        }

        pub fn parse(self: *Self) !void {
            self.args.skip();
            while (self.args.next()) |pair| {
                // it is guaranteed to be a `struct`
                const stripped = pair.name[2..];
                if (pair.value) |value| {
                    try self.modifyFieldValue(U, stripped, value, config.custom_parser);
                } else {
                    try self.invertFieldValue(stripped);
                }
            }
        }
    };
}
