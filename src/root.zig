// module imports
const std = @import("std");
const builtin = @import("builtin");
const parserDefault = @import("value_parser.zig").parseDefault;
// function alias
const print = std.debug.print;
const eql = std.mem.eql;
// struct alias
const Allocator = std.mem.Allocator;
const ArgIterator = std.process.ArgIterator;

const OptPair = struct {
    name: []const u8,
    value: ?[]const u8,

    pub fn single(name: []const u8) OptPair {
        return .{ .name = name, .value = null };
    }

    pub fn paired(name: []const u8, value: []const u8) OptPair {
        return .{
            .name = name,
            .value = value,
        };
    }
};

pub fn isSubcommandStruct(comptime T: type) bool {
    const info = @typeInfo(T);
    if (info != .@"struct") {
        return false;
    }

    return @hasDecl(T, "docs");
}

pub fn getSubcommands(comptime T: type) []const []const u8 {
    comptime var subcommands: []const []const u8 = &.{};

    const info = @typeInfo(T);
    if (info != .@"struct") {
        @compileError("not a struct from `getSubcommand`");
    }

    const fields = info.@"struct".fields;

    inline for (fields) |field| {
        if (comptime isSubcommandStruct(field.type)) {
            subcommands = subcommands ++ &[_][]const u8{field.name};
        }
    }

    return subcommands;
}

pub fn isRegisteredSubcommand(subcommands: []const []const u8, s: []const u8) bool {
    for (subcommands) |subcommand| {
        if (eql(u8, subcommand, s)) {
            return true;
        }
    }
    return false;
}

pub fn hasDefaultFieldValue(comptime T: type) bool {
    const info = @typeInfo(T);
    if (info != .@"struct") {
        const tname = @typeName(T);
        @compileError("ERROR: " ++ tname ++ " must be a struct!");
    }

    const fields = info.@"struct".fields;

    inline for (fields) |field| {
        if (field.default_value_ptr == null) {
            return false;
        }
    }
    return true;
}

pub fn defaultOrNull(comptime T: type) ?T {
    const res = comptime hasDefaultFieldValue(T);
    return if (res) T{} else null;
}

pub fn getPathSuffix(path: []const u8) ?[]const u8 {
    const delimiter: u8 = if (builtin.os.tag == .windows) '\\' else '/';
    for (0..(path.len - 1)) |i| {
        const cursor = path[(path.len - 1) - i];
        if (cursor == delimiter) {
            return path[(path.len - i)..];
        }
    }
    return null;
}

pub fn getTypeSuffix(comptime T: type) ?[]const u8 {
    const tname = @typeName(T);
    for (0..(tname.len - 1)) |i| {
        const cursor = tname[(tname.len - 1) - i];
        if (cursor == '.') {
            return tname[(tname.len - i)..];
        }
    }
    return null;
}

pub fn isLongOption(arg: []const u8) bool {
    return std.mem.containsAtLeast(u8, arg, 1, "--");
}

pub fn isAssignmentOption(arg: []const u8) bool {
    return std.mem.containsAtLeast(u8, arg, 1, "=");
}

pub fn getAssignmentOption(assopt: []const u8) OptPair {
    const eql_idx = std.mem.indexOf(u8, assopt, "=").?;
    const name = assopt[0..(eql_idx)];
    const value = assopt[(eql_idx + 1)..];
    return .paired(name, value);
}

pub fn isDefinedOption(comptime T: type, optname: []const u8) bool {
    const info = @typeInfo(T);
    const fields = info.@"struct".fields;
    var res = false;

    inline for (fields) |field| {
        const field_info = @typeInfo(field.type);
        if (field_info == .@"struct" and @hasDecl(field.type, "docs")) {
            res = isDefinedOption(field.type, optname);
        }
    }

    inline for (fields) |field| {
        if (eql(u8, field.name, optname)) {
            res = true;
        }
    }

    return res;
}

pub fn CreateCLIApp(comptime Template: type) type {
    const subcommands = getSubcommands(Template);

    return struct {
        const Self = @This();

        template: Template,
        args: ArgIterator,
        skipped: ?[]const u8 = null,
        scope: []const u8 = getTypeSuffix(Template).?,

        pub fn init(template: Template, allocator: Allocator) Self {
            const args = std.process.argsWithAllocator(allocator) catch unreachable;
            return Self{ .template = template, .args = args };
        }

        pub fn default() Self {
            var dbg_alloc = std.heap.DebugAllocator(.{}){};
            const alloc = dbg_alloc.allocator();
            const args = std.process.argsWithAllocator(alloc) catch unreachable;

            return Self{
                .template = undefined,
                .args = args,
            };
        }

        pub fn deinit(self: *Self) void {
            self.args.deinit();
        }

        pub fn parse(self: *Self) !void {
            _ = self.args.skip();
            while (self.args.next()) |arg| {
                if (self.skipped) |skipped| {
                    if (isAssignmentOption(skipped) and isRegisteredSubcommand(subcommands, arg)) {
                        const pair = getAssignmentOption(skipped);
                        const stripped = pair.name[2..];
                        self.skipped = null;
                        try self.modifyInnerField(&self.template, stripped, pair.value.?);
                        self.scope = arg;
                        // return
                        continue;
                    }

                    if (isAssignmentOption(skipped)) {
                        const pair = getAssignmentOption(skipped);
                        const stripped = pair.name[2..];
                        self.skipped = null;
                        try self.modifyInnerField(&self.template, stripped, pair.value.?);
                        // return
                        continue;
                    }

                    if (isLongOption(skipped) and isLongOption(arg)) {
                        const tmp = skipped;
                        self.skipped = arg;
                        try self.invertInnerField(&self.template, tmp[2..]);
                        // return;
                        continue;
                    }

                    if (isLongOption(skipped) and isRegisteredSubcommand(subcommands, arg)) {
                        try self.invertInnerField(&self.template, skipped[2..]);
                        self.scope = arg;
                        self.skipped = null;
                        // return;
                        continue;
                    }

                    if (isLongOption(skipped)) {
                        try self.modifyInnerField(&self.template, skipped[2..], arg);
                        continue;
                    }
                }

                if (isLongOption(arg)) {
                    try self.handleLongOption(arg);
                } else if (isRegisteredSubcommand(subcommands, arg)) {
                    self.scope = arg;
                }
            }

            if (self.skipped) |skipped| {
                if (isAssignmentOption(skipped)) {
                    const pair = getAssignmentOption(skipped);
                    const stripped = pair.name[2..];
                    self.skipped = null;
                    try self.modifyInnerField(&self.template, stripped, pair.value.?);
                    return;
                }

                if (isLongOption(skipped)) {
                    const tmp = skipped;
                    self.skipped = null;
                    try self.invertInnerField(&self.template, tmp[2..]);
                    return;
                }
            }
        }

        fn getOptionPair(self: *Self, inner: anytype, optname: []const u8) OptPair {
            if (isAssignmentOption(optname)) {
                return getAssignmentOption(optname);
            }

            const value = self.args.next() orelse {
                return .single(optname);
            };

            if (isLongOption(value)) {
                self.skipped = value;
                return .single(optname);
            }

            if (isRegisteredSubcommand(subcommands, value)) {
                self.scope = value;
                self.skipped = null;
                return .single(optname);
            }

            const inner_info = @typeInfo(@TypeOf(inner.*));
            const fields = inner_info.@"struct".fields;

            inline for (fields) |field| {
                const child_info = @typeInfo(field.type);
                if (isSubcommandStruct(field.type) and child_info == .@"struct") {
                    _ = self.getOptionPair(&@field(inner, field.name), optname);
                }
            }

            const stripped = optname[2..];
            inline for (fields) |field| {
                if (eql(u8, field.name, stripped) and field.type == bool) {
                    self.skipped = null;
                    return .single(optname);
                }
            }

            return .paired(optname, value);
        }

        fn modifyInnerField(self: *Self, inner: anytype, field_name: []const u8, field_value: []const u8) !void {
            const inner_info = @typeInfo(@TypeOf(inner.*));
            const fields = inner_info.@"struct".fields;

            inline for (fields) |field| {
                const child_inner_info = @typeInfo(field.type);
                if (child_inner_info == .@"struct" and eql(u8, field.name, self.scope)) {
                    try self.modifyInnerField(&@field(inner, field.name), field_name, field_value);
                }
            }

            inline for (fields) |field| {
                if (eql(u8, field.name, field_name)) {
                    @field(inner, field.name) = try parserDefault(field.type, field_value);
                }
            }
        }

        fn invertInnerField(self: *Self, inner: anytype, field_name: []const u8) !void {
            const inner_info = @typeInfo(@TypeOf(inner.*));
            const fields = inner_info.@"struct".fields;

            inline for (fields) |field| {
                const child_inner_info = @typeInfo(field.type);
                if (child_inner_info == .@"struct" and eql(u8, field.name, self.scope)) {
                    try self.invertInnerField(&@field(inner, field.name), field_name);
                }
            }

            inline for (fields) |field| {
                if (eql(u8, field.name, field_name) and field.type == bool) {
                    @field(inner, field.name) = !@field(inner, field.name);
                }
            }
        }

        fn handleLongOption(self: *Self, opt: []const u8) !void {
            const pair = self.getOptionPair(&self.template, opt);
            const stripped = pair.name[2..];
            if (pair.value) |value| {
                try self.modifyInnerField(&self.template, stripped, value);
            } else {
                try self.invertInnerField(&self.template, stripped);
            }
        }
    };
}
