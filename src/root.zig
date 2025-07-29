// module imports
const std = @import("std");
const builtin = @import("builtin");
const argparser = @import("argparser.zig");
const parser = @import("value_parser.zig");
// struct aliases
// const ArgumentParserIterator = argparser.ArgumentParserIterator;
const Allocator = std.mem.Allocator;
const ArgIterator = std.process.ArgIterator;
const ArrayListAligned = std.ArrayListAligned;
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

fn getSubcommands(comptime T: type) []const []const u8 {
    comptime var result: []const []const u8 = &.{};
    const info = @typeInfo(T);
    const fields = info.@"struct".fields;
    comptime {
        for (fields) |field| {
            const field_type = @typeInfo(field.type);
            if (field_type == .@"struct" and field.type != Allocator and field.type != std.ArrayList([]const u8)) {
                result = result ++ &[_][]const u8{field.name};
            }
        }
    }
    return result;
}

fn isValidArgsType(comptime T: type) void {
    const typeinfo = @typeInfo(T);
    if (typeinfo != .@"struct") {
        const type_name = @typeName(T);
        @compileError("ERROR: type " ++ type_name ++ " must be a struct");
    }

    const fields = typeinfo.@"struct".fields;
    inline for (fields) |field| {
        const field_info = @typeInfo(field.type);
        if (field_info == .@"struct") {
            isValidArgsType(field.type);
        } else if (eql(u8, field.name, "args") and field.type != std.ArrayList([]const u8)) {
            @compileError("found invalid args");
        }
    }
}

pub fn CLIApp(comptime T: type) type {
    const inner_info = @typeInfo(T);

    if (inner_info != .@"struct") {
        const tname = @typeName(T);
        @compileError("ERROR: " ++ tname ++ " must be a struct!");
    }

    isValidArgsType(T);

    const subcommands = getSubcommands(T);

    return struct {
        const Self = @This();

        inner: T,
        args: ArgIterator,
        allocator: Allocator,
        prev: ?[]const u8 = null,
        search_scope: []const u8 = "",

        pub fn init(allocator: Allocator) Self {
            const iter = std.process.argsWithAllocator(allocator) catch unreachable;
            // const inner: T = if (hasDefaultValues(T)) T{} else undefined;
            return Self{
                .inner = undefined,
                .args = iter,
                .allocator = allocator,
            };
        }
        pub fn deinit(self: *Self) void {
            self.args.deinit();
        }

        pub fn parse(self: *Self) !void {
            const main_cmd = self.args.next().?;
            self.search_scope = getSuffix(main_cmd);
            self.initializeCmdArgs(&self.inner);
            while (self.args.next()) |arg| {
                if (self.prev) |prev| {
                    if (isOption(prev)) {
                        const tmp = prev;
                        self.prev = null;
                        const pair = self.handleOption(&self.inner, tmp);

                        print("PAIR in prev block inside while loop: {s}->{s}\n", .{ pair.name, pair.value orelse "null" });

                        const stripped = pair.name[2..];
                        if (pair.value) |value| try self.modifyInnerField(&self.inner, stripped, value) else try self.invertInnerField(&self.inner, stripped);
                    } else if (isSubcommand(prev)) {
                        self.search_scope = prev;
                        self.prev = null;
                    } else {
                        print("add args inside while loop inside self.prev", .{});
                        try self.addArgsToCmd(&self.inner, prev);
                        self.prev = null;
                    }
                }
                if (isOption(arg)) {
                    const pair = self.handleOption(&self.inner, arg);
                    print("PAIR in isoption(arg) block inside while loop: {s}->{s}\n", .{ pair.name, pair.value orelse "null" });

                    const stripped = pair.name[2..];
                    if (pair.value) |value| try self.modifyInnerField(&self.inner, stripped, value) else try self.invertInnerField(&self.inner, stripped);
                } else if (isSubcommand(arg)) {
                    print("command changed from {s} to {s} in main loop\n", .{ self.search_scope, arg });
                    self.search_scope = arg;
                } else {
                    print("add args inside while loop outside self.prev", .{});
                    try self.addArgsToCmd(&self.inner, arg);
                    self.prev = null;
                }
            }

            if (self.prev) |prev| {
                if (isOption(prev)) {
                    const tmp = prev;
                    self.prev = null;
                    const pair = self.handleOption(&self.inner, tmp);

                    print("PAIR in prev block outside while loop: {s}->{s}\n", .{ pair.name, pair.value orelse "null" });

                    const stripped = pair.name[2..];
                    if (pair.value) |value| try self.modifyInnerField(&self.inner, stripped, value) else try self.invertInnerField(&self.inner, stripped);
                } else if (isSubcommand(prev)) {
                    self.search_scope = prev;
                    self.prev = null;
                } else {
                    print("add args outside while loop inside self.prev", .{});
                    try self.addArgsToCmd(&self.inner, prev);
                    self.prev = null;
                }
            }
        }

        fn modifyInnerField(self: *Self, s: anytype, optname: []const u8, value: []const u8) !void {
            const anon_type_info = @typeInfo(@TypeOf(s.*));
            const fields = anon_type_info.@"struct".fields;

            inline for (fields) |field| {
                const child_info = @typeInfo(field.type);
                if (isSubcommand(self.search_scope) and child_info == .@"struct" and eql(u8, field.name, self.search_scope)) {
                    try self.modifyInnerField(&@field(s, field.name), optname, value);
                    return;
                }
            }

            inline for (fields) |field| {
                if (eql(u8, field.name, optname)) {
                    @field(s, field.name) = try parseDefault(field.type, value);
                    return;
                }
            }

            return error.UnrecognizedFlag;
        }

        fn invertInnerField(self: *Self, s: anytype, optname: []const u8) !void {
            const anon_type_info = @typeInfo(@TypeOf(s.*));
            const fields = anon_type_info.@"struct".fields;

            inline for (fields) |field| {
                const child_info = @typeInfo(field.type);
                if (isSubcommand(self.search_scope) and child_info == .@"struct" and eql(u8, field.name, self.search_scope)) {
                    try self.invertInnerField(&@field(s, field.name), optname);
                    return;
                }
            }

            inline for (fields) |field| {
                if (eql(u8, field.name, optname) and field.type == bool) {
                    @field(s, field.name) = !@field(s, field.name);
                    return;
                } else if (eql(u8, field.name, optname) and field.type != bool) {
                    return error.UnableToInvert;
                }
            }

            return error.UnrecognizedFlag;
        }

        fn initializeCmdArgs(self: *Self, s: anytype) void {
            const sinfo = @typeInfo(@TypeOf(s.*));
            const fields = sinfo.@"struct".fields;

            inline for (fields) |field| {
                const child_info = @typeInfo(field.type);
                //if (isSubcommand(self.search_scope) and child_info == .@"struct" and eql(u8, field.name, self.search_scope)) {
                //    self.initializeCmdArgs(&@field(s, field.name));
                //}
                if (child_info == .@"struct" and field.type != Allocator and field.type != std.ArrayList([]const u8)) {
                    self.initializeCmdArgs(&@field(s, field.name));
                }
            }

            inline for (fields) |field| {
                if (eql(u8, field.name, "args") and field.type == std.ArrayList([]const u8)) {
                    @field(s, field.name) = std.ArrayList([]const u8).init(self.allocator);
                }
            }
        }

        fn addArgsToCmd(self: *Self, s: anytype, arg: []const u8) !void {
            const sinfo = @typeInfo(@TypeOf(s.*));
            const fields = sinfo.@"struct".fields;

            inline for (fields) |field| {
                const child_info = @typeInfo(field.type);
                if (isSubcommand(self.search_scope) and child_info == .@"struct" and eql(u8, field.name, self.search_scope)) {
                    try self.addArgsToCmd(&@field(s, field.name), arg);
                    return;
                }
            }

            inline for (fields) |field| {
                if (eql(u8, field.name, "args") and field.type == std.ArrayList([]const u8)) {
                    try s.args.append(arg);
                }
            }
        }

        fn handleOption(self: *Self, s: anytype, arg: []const u8) Pair {
            //if (self.prev) |prev| {
            //    print("hey found inside handleOption {s}\n", .{prev});
            //    if (isOption(prev)) {
            //        const tmp = prev;
            //        self.prev = null;
            //        return self.handleOption(tmp);
            //    }
            //}
            const sinfo = @typeInfo(@TypeOf(s.*));
            const fields = sinfo.@"struct".fields;

            inline for (fields) |field| {
                const ch_info = @typeInfo(field.type);
                if (isSubcommand(self.search_scope) and ch_info == .@"struct" and eql(u8, field.name, self.search_scope)) {
                    return self.handleOption(&@field(s, field.name), arg);
                }
            }

            if (isAssignmentOption(arg)) {
                return extractAssignmentOption(arg);
            }

            const item = self.args.next() orelse return Pair{ .name = arg, .value = null };
            if (isAssignmentOption(item)) {
                self.prev = item;
                return Pair{ .name = arg, .value = null };
            }

            if (isOption(item)) {
                self.prev = item;
                return Pair{ .name = arg, .value = null };
            }

            if (isSubcommand(item)) {
                // print("command changed from {s} to {s} in handleOption", .{ self.search_scope, item });
                // self.search_scope = item;
                self.prev = item;
                return Pair{ .name = arg, .value = null };
            }

            //print("scope: {s}", .{self.search_scope});
            //print("KVPAIR: {s}->{s}", .{ arg, item });
            inline for (fields) |field| {
                //print("field name of the current scope: {s}\n", .{field.name});
                const stripped = arg[2..];
                if (eql(u8, field.name, stripped) and field.type == bool) {
                    self.prev = item;
                    return Pair{ .name = arg, .value = null };
                }
            }

            self.prev = null;
            return Pair{ .name = arg, .value = item };
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

        fn isOption(arg: []const u8) bool {
            return std.mem.startsWith(u8, arg, "--") and !std.mem.containsAtLeast(u8, arg, 1, "args");
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
