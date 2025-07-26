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
    const info = @typeInfo(T);

    if (info != .@"struct") {
        const tname = @typeName(T);
        @compileError("ERROR: " ++ tname ++ " must be a struct!");
    }

    const subcommands = getSubcommands(T);

    return struct {
        const Self = @This();

        inner: T,
        iter: ArgIterator,
        prev: ?[]const u8 = null,

        pub fn init(allocator: Allocator) Self {
            const iter = std.process.argsWithAllocator(allocator) catch unreachable;
            // const inner: T = if (hasDefaultValues(T)) T{} else undefined;
            return Self{
                .inner = undefined,
                .iter = iter,
            };
        }
        pub fn deinit(self: *Self) void {
            self.iter.deinit();
        }

        pub fn parse(self: *Self) !void {
            // `git --no-pager diff --staged src/main.zig`
            // `<main-command> <flags...> <args...> <sub-command> <flags...> <args...>`
            const main_command = self.iter.next().?;
            const bin_path = getSuffix(main_command);
            print("hey found main command {s}\n", .{bin_path});

            while (self.iter.next()) |arg| {
                if (self.prev) |prev| {
                    if (isOption(arg)) {
                        const tmp = prev;
                        self.prev = arg;
                        const pair = Pair{ .name = tmp, .value = null };
                        print("hey found flag {s}->{any}\n", .{ pair.name, pair.value });
                        continue;
                    } else {
                        const tmp = prev;
                        self.prev = null;
                        const pair = Pair{ .name = tmp, .value = arg };
                        print("hey found flag {s}->{s}\n", .{ pair.name, pair.value.? });
                        continue;
                    }
                }
                var curr_cmd = main_command;
                if (isOption(arg)) {
                    print("hey is option! {s}\n", .{arg});
                    const pair = self.getOptionValue(arg);
                    if (pair.value) |value| {
                        print("hey found flag {s}->{s}\n", .{ pair.name, value });
                    } else {
                        print("hey found flag {s}->{any}\n", .{ pair.name, pair.value });
                    }
                } else if (isSubcommand(arg)) {
                    curr_cmd = arg;
                    print("hey found subcommand {s}\n", .{curr_cmd});
                } else {
                    print("hey found arguments {s}\n", .{arg});
                }
            }
        }

        fn getOptionValue(self: *Self, flag: []const u8) Pair {
            if (isAssignmentOption(flag)) {
                return extractAssignmentOption(flag);
            }

            const possibleValue = self.iter.next() orelse return Pair{ .name = flag, .value = null };
            if (isOption(possibleValue)) {
                self.prev = possibleValue;
                return Pair{ .name = flag, .value = null };
            }

            if (isSubcommand(possibleValue)) {
                print("hey found subcommand {s}\n", .{possibleValue});
                return Pair{ .name = flag, .value = null };
            }

            const stripped = flag[2..];
            inline for (info.@"struct".fields) |field| {
                if (eql(u8, field.name, stripped)) {
                    if (field.type == bool) {
                        return Pair{ .name = flag, .value = null };
                    }
                }
            }

            return Pair{ .name = flag, .value = possibleValue };
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

        fn extractAssignmentOption(flag: []const u8) Pair {
            const index = std.mem.indexOf(u8, flag, "=").?;
            const name = flag[0..index];
            const value = flag[(index + 1)..];
            return Pair{ .name = name, .value = value };
        }

        fn isOption(arg: []const u8) bool {
            return std.mem.startsWith(u8, arg, "--");
        }

        fn isAssignmentOption(arg: []const u8) bool {
            return std.mem.containsAtLeast(u8, arg, 1, "=");
        }

        fn isSubcommand(arg: []const u8) bool {
            for (subcommands) |subcommand| {
                if (eql(u8, arg, subcommand)) {
                    return true;
                }
            }
            return false;
        }
    };
}
