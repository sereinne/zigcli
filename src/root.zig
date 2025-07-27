// module imports
const std = @import("std");
const builtin = @import("builtin");
const argparser = @import("argparser.zig");
const parser = @import("value_parser.zig");
// struct aliases
// const ArgumentParserIterator = argparser.ArgumentParserIterator;
const Allocator = std.mem.Allocator;
const ArgIterator = std.process.ArgIterator;
const Parser = parser.Parser;
const Pair = argparser.Pair;
pub const parseWithFallback = parser.parseWithFallback;
pub const parseDefault = parser.parseDefault;
// function aliases
const print = std.debug.print;
const eql = std.mem.eql;

pub fn Config(comptime T: type) type {
    return struct {
        fallback_parser: ?Parser(T) = null,
    };
}

fn hasDefaultValues(comptime T: type) bool {
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

pub fn getSubcommands(comptime T: type) []const []const u8 {
    comptime var result: []const []const u8 = &.{};
    const info = @typeInfo(T);
    const fields = info.@"struct".fields;
    comptime {
        for (fields) |field| {
            const field_type = @typeInfo(field.type);
            if (field_type == .@"struct") {
                result = result ++ &[_][]const u8{field.name};
            }
        }
    }
    return result;
}

pub fn CLIApp(comptime T: type) type {
    const inner_info = @typeInfo(T);

    if (inner_info != .@"struct") {
        const tname = @typeName(T);
        @compileError("ERROR: " ++ tname ++ " must be a struct!");
    }

    const subcommands = getSubcommands(T);

    return struct {
        const Self = @This();

        inner: T,
        args: ArgIterator,

        pub fn init(allocator: Allocator) Self {
            const iter = std.process.argsWithAllocator(allocator) catch unreachable;
            // const inner: T = if (hasDefaultValues(T)) T{} else undefined;
            return Self{
                .inner = undefined,
                .args = iter,
            };
        }
        pub fn deinit(self: *Self) void {
            self.args.deinit();
        }

        fn modifyFieldRecursive(s: anytype, scope: []const u8, key: []const u8, value: []const u8) !void {
            if (!isPointerToStruct(@TypeOf(s))) {
                return error.NotAPtrToAStruct;
            }

            const info = @typeInfo(@TypeOf(s.*));
            const fields = info.@"struct".fields;

            inline for (fields) |field| {
                const child_info = @typeInfo(field.type);
                if (isSubcommand(scope) and child_info == .@"struct") {
                    try modifyFieldRecursive(&@field(s, field.name), scope, key, value);
                    return;
                }
            }

            inline for (fields) |field| {
                if (eql(u8, field.name, key)) {
                    @field(s, field.name) = try parseDefault(field.type, value);
                    return;
                }
            }

            return error.UnknownFlag;
        }

        fn invertFieldRecursive(s: anytype, scope: []const u8, key: []const u8) !void {
            if (!isPointerToStruct(@TypeOf(s))) {
                return error.NotAPtrToAStruct;
            }

            const info = @typeInfo(@TypeOf(s.*));
            const fields = info.@"struct".fields;

            inline for (fields) |field| {
                const child_info = @typeInfo(field.type);
                if (isSubcommand(scope) and child_info == .@"struct") {
                    try invertFieldRecursive(&@field(s, field.name), scope, key);
                    return;
                }
            }

            inline for (fields) |field| {
                if (eql(u8, field.name, key) and field.type == bool) {
                    @field(s, field.name) = !@field(s, field.name);
                    return;
                }
            }

            return error.UnknownFlag;
        }

        fn addArgRecursive(s: anytype, scope: []const u8, cmd_arg: []const u8) !void {
            if (!isPointerToStruct(@TypeOf(s))) {
                return error.NotAPtrToAStruct;
            }

            const info = @typeInfo(@TypeOf(s.*));
            const fields = info.@"struct".fields;

            inline for (fields) |field| {
                const child_info = @typeInfo(field.type);
                if (isSubcommand(scope) and child_info == .@"struct") {
                    try addArgRecursive(&@field(s, field.name), scope, cmd_arg);
                    return;
                }
            }

            inline for (fields) |field| {
                if (eql(u8, field.name, "arg") and field.type == []const u8) {
                    @field(s, field.name) = cmd_arg;
                }
            }
        }

        pub fn parse(self: *Self) !void {
            const exe_path = self.args.next().?;
            const main_scope = getSuffix(exe_path);
            var curr_scope = main_scope;
            while (self.args.next()) |arg| {
                if (isAssignmentOption(arg)) {
                    const pair = extractAssignmentOption(arg);
                    const stripped = pair.name[2..];
                    try modifyFieldRecursive(&self.inner, curr_scope, stripped, pair.value.?);
                } else if (isTrailingOption(arg)) {
                    const stripped = arg[2..];
                    try invertFieldRecursive(&self.inner, curr_scope, stripped);
                } else if (isSubcommand(arg)) {
                    curr_scope = arg;
                } else {
                    try addArgRecursive(&self.inner, curr_scope, arg);
                }
            }
        }

        fn extractAssignmentOption(opt: []const u8) Pair {
            const eq_sign_idx = std.mem.indexOf(u8, opt, "=").?;
            const name = opt[0..eq_sign_idx];
            const value = opt[(eq_sign_idx + 1)..];
            return Pair{ .name = name, .value = value };
        }

        fn getSuffix(path: []const u8) []const u8 {
            const delimiter = if (builtin.os.tag == .windows) "\\" else "/";
            const length = path.len - 1;
            for (0..length) |i| {
                const curr_ch = path[length - i];
                if (curr_ch == delimiter[0]) {
                    return path[(length - i + 1)..];
                }
            }
            return "";
        }

        fn isAssignmentOption(arg: []const u8) bool {
            return std.mem.containsAtLeast(u8, arg, 1, "=");
        }

        fn isTrailingOption(arg: []const u8) bool {
            return std.mem.startsWith(u8, arg, "--");
        }

        fn isSubcommand(arg: []const u8) bool {
            for (subcommands) |subcommand| {
                if (eql(u8, arg, subcommand)) {
                    return true;
                }
            }
            return false;
        }

        fn findSubcommand(arg: []const u8) ?[]const u8 {
            for (subcommands) |subcommand| {
                if (eql(u8, arg, subcommand)) {
                    return subcommand;
                }
            }
            return null;
        }

        fn isPointerToStruct(comptime V: type) bool {
            const info = @typeInfo(V);
            return switch (info) {
                .pointer => |ptr| {
                    const child_info = @typeInfo(ptr.child);
                    if (child_info != .@"struct") {
                        return false;
                    }
                    return true;
                },
                else => return false,
            };
        }
    };
}
