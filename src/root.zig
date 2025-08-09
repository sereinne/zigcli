// this code divider is from: https://github.com/maysara-elshewehy
// ╔══════════════════════════════════════ module imports ══════════════════════════════════════╗
const std = @import("std");
const builtin = @import("builtin");
const parseDefault = @import("parse_string.zig").parseDefault;
// ╚══════════════════════════════════════ module imports ══════════════════════════════════════╝
//
// ╔══════════════════════════════════════ function alias ══════════════════════════════════════╗
const print = std.debug.print;
const eql = std.mem.eql;
// ╚══════════════════════════════════════ function alias ══════════════════════════════════════╝
//
// ╔══════════════════════════════════════ struct alias ══════════════════════════════════════╗
const Allocator = std.mem.Allocator;
const ArgIterator = std.process.ArgIterator;
const ArrayList = std.ArrayList;
// ╚══════════════════════════════════════ struct alias ══════════════════════════════════════╝
//
// ╔══════════════════════════════════════ struct definition ══════════════════════════════════════╗
const Pair = struct {
    name: []const u8,
    value: ?[]const u8 = null,

    fn single(name: []const u8) Pair {
        return Pair{
            .name = name,
        };
    }

    fn paired(name: []const u8, value: []const u8) Pair {
        return Pair{
            .name = name,
            .value = value,
        };
    }
};
// ╚══════════════════════════════════════ struct definition ══════════════════════════════════════╝

// ╔══════════════════════════════════════ comptime helpers ══════════════════════════════════════╗
pub fn getValidFlags(comptime T: type) []const []const u8 {
    comptime var valid_flags: []const []const u8 = &.{};

    const info = @typeInfo(T);
    if (info != .@"struct") {
        const tname = @typeName(T);
        @compileError("ERROR: " ++ tname ++ " is not a struct!\n");
    }

    const fields = info.@"struct".fields;
    inline for (fields) |field| {
        const field_info = @typeInfo(field.type);
        comptime {
            if (isSubcommandStruct(field.type) and field_info == .@"struct") {
                valid_flags = valid_flags ++ getValidFlags(field.type);
            }
        }
    }

    inline for (fields) |field| {
        if (!comptime isSubcommandStruct(field.type)) {
            valid_flags = valid_flags ++ &[_][]const u8{field.name};
        }
    }

    return valid_flags;
}

pub fn getSubcommands(comptime T: type) []const []const u8 {
    comptime var subcommands: []const []const u8 = &.{};

    const info = @typeInfo(T);
    if (info != .@"struct") {
        const tname = @typeName(T);
        @compileError("ERROR: " ++ tname ++ " is not a struct!\n");
    }

    const fields = info.@"struct".fields;
    inline for (fields) |field| {
        const field_info = @typeInfo(field.type);
        comptime {
            if (isSubcommandStruct(field.type) and field_info == .@"struct") {
                subcommands = subcommands ++ getSubcommands(field.type);
            }
        }
    }

    inline for (fields) |field| {
        if (comptime isSubcommandStruct(field.type)) {
            subcommands = subcommands ++ &[_][]const u8{field.name};
        }
    }

    return subcommands;
}

pub fn isSubcommandStruct(comptime T: type) bool {
    const info = @typeInfo(T);
    if (info != .@"struct") return false;

    return @hasDecl(T, "docs");
}

pub fn checkValidArgsFields(comptime T: type) bool {
    const typeinfo = @typeInfo(T);
    if (typeinfo != .@"struct") {
        return false;
    }

    const fields = typeinfo.@"struct".fields;
    var result = true;
    inline for (fields) |field| {
        const field_info = @typeInfo(field.type);
        if (isSubcommandStruct(field.type) and field_info == .@"struct") {
            const res = checkValidArgsFields(field.type);
            if (res == false) {
                return res;
            }
        } else if (eql(u8, field.name, "args") and field.type != std.ArrayList([]const u8)) {
            return false;
        } else if (eql(u8, field.name, "args") and field.type == std.ArrayList([]const u8)) {
            result = true;
        }
    }
    return result;
}

fn isAvailableFlag(valid_flags: []const []const u8, flag: []const u8) bool {
    for (valid_flags) |valid_flag| {
        if (eql(u8, valid_flag, flag)) {
            return true;
        }
    }
    return false;
}

fn isInSubcommand(subcommands: []const []const u8, arg: []const u8) bool {
    for (subcommands) |subcommand| {
        if (eql(u8, arg, subcommand)) {
            return true;
        }
    }
    return false;
}
// ╚══════════════════════════════════════ comptime helpers ══════════════════════════════════════╝

/// function to create CLI app from a struct `T`.
/// These are the cases when it will raise a compilation errors
/// - when `T` is not a `struct`
/// - when `T` does not have a declaration named `docs` with a type `[]const [3][]const u8`
/// - when `T` has a field `args` that has a type other than `std.ArrayList([]const u8)`. `zigcli` will use this field to store arguments for a command
/// or a subcommand.
pub fn CreateApp(comptime T: type) type {
    const tinfo = @typeInfo(T);
    if (tinfo != .@"struct") {
        const tname = @typeName(T);
        @compileError("ERROR: " ++ tname ++ " is not a struct!");
    }

    // even though `T` is the main command, it is similar to a subcommand struct  (has a decl named `docs`)
    if (!isSubcommandStruct(T)) {
        const tname = @typeName(T);
        @compileError("ERROR: " ++ tname ++ " is doesn't have a public `docs` declaration");
    }

    if (!checkValidArgsFields(T)) {
        const tname = @typeName(T);
        @compileError("ERROR: " ++ tname ++ " has a field `args` that has a type other than `Arraylist([]const u8)`\n");
    }

    const valid_flags = getValidFlags(T);
    const subcommands = getSubcommands(T);

    return struct {
        const Self = @This();
        /// users template of a CLI app.
        inner: T,
        /// allocate `args` on heap.
        allocator: Allocator,
        /// iterator over CLI args.
        args: ArgIterator,
        /// store items that are skipped and haven't been processed by the `parse` function
        queue: ?[]const u8 = null,
        /// initial search scope of the flag, `null` means the search scope is in the main command (not any subcommand)
        scope: []const u8 = "",
        // ╔══════════════════════════════════════ private flag utilities ══════════════════════════════════════╗
        fn isLongOption(arg: []const u8) bool {
            return std.mem.startsWith(u8, arg, "--");
        }

        fn isBooleanOption(opt: []const u8) bool {
            const t_info = @typeInfo(T);
            const fields = t_info.@"struct".fields;

            inline for (fields) |field| {
                if (eql(u8, field.name, opt[2..]) and field.type == bool) {
                    return true;
                }
            }

            return false;
        }

        fn extractOption(self: *Self, arg: []const u8) !Pair {
            if (isAssignmentOption(arg)) {
                return try getAssignmentOption(arg);
            }

            if (!isAvailableFlag(valid_flags, arg[2..])) {
                return error.UnrecognizedFlag;
            }

            const value = self.args.next() orelse {
                self.queue = null;
                return .single(arg);
            };

            if (isLongOption(value)) {
                self.queue = value;
                return .single(arg);
            }

            if (isInSubcommand(subcommands, arg)) {
                self.queue = null;
                self.scope = arg;
                return .single(arg);
            }

            if (isBooleanOption(arg)) {
                self.queue = null;
                return .single(arg);
            }

            return .paired(arg, value);
        }

        fn extractSkippedOptionInLoop(self: *Self, arg: []const u8, possible_value: []const u8) !Pair {
            if (isAssignmentOption(arg)) {
                return getAssignmentOption(arg);
            }

            if (!isAvailableFlag(valid_flags, arg[2..])) {
                return error.UnrecognizedFlag;
            }

            if (isLongOption(arg)) {
                if (isAssignmentOption(possible_value)) {
                    self.queue = possible_value;
                    return .single(arg);
                }

                if (isLongOption(possible_value)) {
                    self.queue = possible_value;
                    return .single(arg);
                }

                if (isInSubcommand(subcommands, possible_value)) {
                    self.queue = null;
                    self.scope = possible_value;
                    return .single(arg);
                }

                if (isBooleanOption(arg)) {
                    self.queue = null;
                    return .single(arg);
                }
            }

            return .paired(arg, possible_value);
        }

        fn extractSkippedOptionOutsideLoop(self: *Self, arg: []const u8) !Pair {
            if (isAssignmentOption(arg)) {
                return getAssignmentOption(arg);
            }

            if (isLongOption(arg)) {
                self.queue = null;
                return .single(arg);
            }

            return error.Unimplemented;
        }

        fn handleSkippedOptionInLoop(self: *Self, arg: []const u8, possible_value: []const u8) !void {
            const pair = try self.extractSkippedOptionInLoop(arg, possible_value);
            print("INFO: (PAIR): {s}->{s}\n", .{ pair.name, pair.value orelse "null" });
            const stripped = pair.name[2..];
            if (pair.value) |value| {
                try self.modifyField(&self.inner, stripped, value);
            } else {
                try self.invertField(&self.inner, stripped);
            }
        }

        fn handleSkippedOptionOutsideLoop(self: *Self, arg: []const u8) !void {
            const pair = try self.extractSkippedOptionOutsideLoop(arg);
            print("INFO: (PAIR): {s}->{s}\n", .{ pair.name, pair.value orelse "null" });
            const stripped = pair.name[2..];
            try self.invertField(&self.inner, stripped);
        }

        fn handleLongOption(self: *Self, arg: []const u8) !void {
            const pair = try self.extractOption(arg);
            print("INFO: (PAIR): {s}->{s}\n", .{ pair.name, pair.value orelse "null" });
            const stripped = pair.name[2..];
            if (pair.value) |value| {
                try self.modifyField(&self.inner, stripped, value);
            } else {
                try self.invertField(&self.inner, stripped);
            }
        }

        fn isAssignmentOption(arg: []const u8) bool {
            return std.mem.containsAtLeast(u8, arg, 1, "=");
        }

        fn getAssignmentOption(arg: []const u8) Pair {
            const idx = std.mem.indexOf(u8, arg, "=").?;
            const key = arg[2..idx];
            const value = arg[(idx + 1)..];
            return .paired(key, value);
        }
        // ╚══════════════════════════════════════ private flag utilities ══════════════════════════════════════╝
        ///
        // ╔══════════════════════════════════════ modification utilities ══════════════════════════════════════╗
        fn modifyField(self: *Self, inner: anytype, flag_name: []const u8, flag_value: []const u8) !void {
            const inner_info = @typeInfo(@TypeOf(inner.*));
            const fields = inner_info.@"struct".fields;

            inline for (fields) |field| {
                const field_info = @typeInfo(field.type);
                if (isSubcommandStruct(field.type) and field_info == .@"struct" and eql(u8, field.name, self.scope)) {
                    try self.modifyField(&@field(inner, field.name), flag_name, flag_value);
                    return;
                }
            }

            inline for (fields) |field| {
                if (eql(u8, field.name, flag_name)) {
                    @field(inner, field.name) = try parseDefault(field.type, flag_value);
                    return;
                }
            }

            return error.NoFlagFoundInScope;
        }

        fn invertField(self: *Self, inner: anytype, flag_name: []const u8) !void {
            const inner_info = @typeInfo(@TypeOf(inner.*));
            const fields = inner_info.@"struct".fields;

            inline for (fields) |field| {
                const field_info = @typeInfo(field.type);
                if (isSubcommandStruct(field.type) and field_info == .@"struct") {
                    try self.invertField(&@field(inner, field.name), flag_name);
                }
            }

            inline for (fields) |field| {
                if (eql(u8, field.name, flag_name) and field.type == bool) {
                    @field(inner, field.name) = !@field(inner, field.name);
                }
            }
        }
        // ╚══════════════════════════════════════ modification utilities ══════════════════════════════════════╝
        //
        // ╔══════════════════════════════════════ public functions ══════════════════════════════════════╗
        /// initialize with custom `Allocator`
        /// the reason why there is no default is because the user must pass an `Allocator` that has a longer lifetime than `zigcli`.
        /// if there is a function called `default` that creates the allocator in the `defualt` function stack , it will be dropped after executing the
        /// `default`.
        pub fn init(allocator: Allocator) Self {
            // panics when unable to allocate CLI args
            const args = std.process.argsWithAllocator(allocator) catch unreachable;
            return .{
                .inner = undefined,
                .allocator = allocator,
                .args = args,
            };
        }

        /// gets the inner value
        pub fn getInner(self: *Self) *T {
            return &self.inner;
        }

        /// deinitialize allocated heap memory used by `zigcli`
        pub fn deinit(self: *Self) void {
            self.args.deinit();
            self.deinitializeCmdArgs(&self.inner);
        }

        /// parse CLI arguments and modify `inner` fileld.
        pub fn parse(self: *Self) !void {
            _ = self.args.skip();
            self.initializeCmdArgs(&self.inner);
            while (self.args.next()) |arg| {
                if (isLongOption(arg) and !isAssignmentOption(arg)) {
                    return error.UnsupportedFlagType;
                } else if (isAssignmentOption(arg)) {
                    const pair = getAssignmentOption(arg);
                    try self.modifyField(&self.inner, pair.name, pair.value.?);
                } else if (isInSubcommand(subcommands, arg)) {
                    self.scope = arg;
                } else {
                    try self.addCmdArgs(&self.inner, arg);
                }
            }
        }
        // ╚══════════════════════════════════════ public functions ══════════════════════════════════════╝

        // ╔══════════════════════════════════════ private functions ══════════════════════════════════════╗
        pub fn initializeCmdArgs(self: *Self, inner: anytype) void {
            const typeinfo = @typeInfo(@TypeOf(inner.*));
            const fields = typeinfo.@"struct".fields;

            inline for (fields) |field| {
                const field_info = @typeInfo(field.type);
                if (isSubcommandStruct(field.type) and field_info == .@"struct") {
                    // print("going into for initializing args {s}\n", .{field.name});
                    self.initializeCmdArgs(&@field(inner, field.name));
                } else if (eql(u8, field.name, "args") and field.type == std.ArrayList([]const u8)) {
                    // print("initializing args...\n", .{});
                    @field(inner, field.name) = std.ArrayList([]const u8).init(self.allocator);
                }
            }
        }

        pub fn deinitializeCmdArgs(self: *Self, inner: anytype) void {
            const typeinfo = @typeInfo(@TypeOf(inner.*));
            const fields = typeinfo.@"struct".fields;

            inline for (fields) |field| {
                const field_info = @typeInfo(field.type);
                if (isSubcommandStruct(field.type) and field_info == .@"struct") {
                    // print("going into for deinitializing args {s}\n", .{field.name});
                    self.deinitializeCmdArgs(&@field(inner, field.name));
                } else if (eql(u8, field.name, "args") and field.type == std.ArrayList([]const u8)) {
                    // print("deinitializing args...\n", .{});
                    @field(inner, field.name).deinit();
                }
            }
        }

        pub fn addCmdArgs(self: *Self, inner: anytype, arg: []const u8) !void {
            const typeinfo = @typeInfo(@TypeOf(inner.*));
            const fields = typeinfo.@"struct".fields;

            inline for (fields) |field| {
                const field_info = @typeInfo(field.type);
                if (isSubcommandStruct(field.type) and field_info == .@"struct" and eql(u8, field.name, self.scope)) {
                    try self.addCmdArgs(&@field(inner, field.name), arg);
                    return;
                }
            }

            inline for (fields) |field| {
                if (eql(u8, field.name, "args") and field.type == std.ArrayList([]const u8)) {
                    // try @field(inner, field.name).append(arg);
                    try inner.args.append(arg);
                }
            }
        }
        // ╚══════════════════════════════════════ private functions ══════════════════════════════════════╝
    };
}
