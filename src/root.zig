// module imports
const std = @import("std");
const argparser = @import("argparser.zig");
const parser = @import("value_parser.zig");
// struct aliases
const ArgumentParserIterator = argparser.ArgumentParserIterator;
const Allocator = std.mem.Allocator;
const Parser = parser.Parser;
// function aliases
const print = std.debug.print;
const eql = std.mem.eql;

pub fn Config(comptime T: type) type {
    return struct {
        fallback_parser: ?Parser(T) = null,
    };
}

pub fn hasDefaultValues(comptime T: type) bool {
    const type_info = @typeInfo(T);
    if (type_info != .@"struct") {
        return false;
    }

    const struct_fields = type_info.@"struct".fields;
    inline for (struct_fields) |field| {
        if (field.default_value_ptr == null) {
            return false;
        }
    }
    return true;
}

pub fn CLIApp(comptime CLITemplate: type, comptime Fallback: type, comptime config: Config(Fallback)) type {
    const type_info = @typeInfo(CLITemplate);

    if (type_info != .@"struct") {
        const name = @typeName(CLITemplate);
        @compileError("ERROR: type " ++ name ++ " is not a struct!");
    }

    const struct_info = type_info.@"struct";
    const struct_fields = struct_info.fields;

    return struct {
        const Self = @This();

        inner: CLITemplate,
        argsiter: ArgumentParserIterator,

        pub fn init(allocator: Allocator) Self {
            const argiter = std.process.argsWithAllocator(allocator) catch unreachable;
            return Self{ .inner = if (hasDefaultValues(CLITemplate)) CLITemplate{} else undefined, .argsiter = ArgumentParserIterator.init(argiter) };
        }

        pub fn default() Self {
            var dbg_allocator = std.heap.DebugAllocator(.{}){};
            const allocator = dbg_allocator.allocator();
            const argiter = std.process.argsWithAllocator(allocator) catch unreachable;
            return Self{
                .inner = if (hasDefaultValues(CLITemplate)) CLITemplate{} else undefined,
                .argsiter = ArgumentParserIterator.init(argiter),
            };
        }

        pub fn deinit(self: *Self) void {
            self.argsiter.deinit();
        }

        pub fn getInner(self: *Self) *CLITemplate {
            return &self.inner;
        }

        fn modifyValue(self: *Self, comptime T: type, cli_flag: []const u8, cli_value: []const u8) !void {
            inline for (struct_fields) |field| {
                if (eql(u8, field.name, cli_flag)) {
                    @field(self.inner, field.name) = try parser.parseWithFallback(field.type, T, cli_value, config.fallback_parser);
                }
            }
        }

        fn invertValue(self: *Self, cli_flag: []const u8) void {
            inline for (struct_fields) |field| {
                if (eql(u8, field.name, cli_flag) and field.type == bool) {
                    @field(self.inner, field.name) = !@field(self.inner, field.name);
                }
            }
        }

        pub fn parse(self: *Self) !void {
            while (self.argsiter.next()) |pair| {
                const stripped = pair.name[2..];
                if (pair.value) |value| {
                    try self.modifyValue(Fallback, stripped, value);
                } else {
                    self.invertValue(stripped);
                }
            }
        }
    };
}
