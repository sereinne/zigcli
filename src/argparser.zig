// module import
const std = @import("std");
// type alias
pub const Args = []const []const u8;
// struct alias
const ArgIterator = std.process.ArgIterator;
pub const Pair = struct {
    name: []const u8,
    value: ?[]const u8,
};

fn isAssignmentOption(flag: []const u8) bool {
    return std.mem.containsAtLeast(u8, flag, 1, "=");
}

fn isOption(flag: []const u8) bool {
    return std.mem.startsWith(u8, flag, "--");
}

pub const ArgumentParserFromSlice = struct {
    const Self = @This();

    inner: Args,
    prev: ?[]const u8 = null,
    idx: usize = 0,
    pub fn init(inner: Args) Self {
        return Self{
            .inner = inner,
        };
    }

    pub fn next_arg(self: *Self) ?[]const u8 {
        const length = self.inner.len - 1;
        if (self.idx > length) {
            self.idx = 0;
            return null;
        }
        const res = self.inner[self.idx];
        self.idx += 1;
        return res;
    }

    pub fn next(self: *Self) ?Pair {
        if (self.prev) |prev| {
            if (isAssignmentOption(prev)) {
                const eq_index = std.mem.indexOf(u8, prev, "=") orelse unreachable;
                const flagname = prev[0..eq_index];
                const value = prev[(eq_index + 1)..];
                self.prev = null;
                return Pair{ .name = flagname, .value = value };
            }
            const item = self.next_arg() orelse {
                const tmp = prev;
                self.prev = null;
                return Pair{ .name = tmp, .value = null };
            };
            if (isOption(item)) {
                const tmp = prev;
                self.prev = item;
                return Pair{ .name = tmp, .value = null };
            }
            const tmp = prev;
            self.prev = null;
            return Pair{ .name = tmp, .value = item };
        }

        const item = self.next_arg() orelse return null;
        if (isAssignmentOption(item)) {
            const eq_index = std.mem.indexOf(u8, item, "=") orelse unreachable;
            const flagname = item[0..eq_index];
            const value = item[(eq_index + 1)..];
            return Pair{ .name = flagname, .value = value };
        }

        const possibleValue = self.next_arg() orelse return Pair{ .name = item, .value = null };
        if (isOption(possibleValue)) {
            self.prev = possibleValue;
            return Pair{ .name = item, .value = null };
        }
        return Pair{ .name = item, .value = possibleValue };
    }
};

pub const ArgumentParserIterator = struct {
    const Self = @This();

    args: ArgIterator,
    prev: ?[]const u8,
    pub fn init(args: ArgIterator) Self {
        return Self{
            .args = args,
            .prev = null,
        };
    }

    pub fn next(self: *Self) ?Pair {
        if (self.prev) |prev| {
            if (isAssignmentOption(prev)) {
                const eq_index = std.mem.indexOf(u8, prev, "=") orelse unreachable;
                const flagname = prev[0..eq_index];
                const value = prev[(eq_index + 1)..];
                self.prev = null;
                return Pair{ .name = flagname, .value = value };
            }
            const item = self.args.next() orelse {
                const tmp = prev;
                self.prev = null;
                return Pair{ .name = tmp, .value = null };
            };
            if (isOption(item)) {
                const tmp = prev;
                self.prev = item;
                return Pair{ .name = tmp, .value = null };
            }
            const tmp = prev;
            self.prev = null;
            return Pair{ .name = tmp, .value = item };
        }

        const item = self.args.next() orelse return null;
        if (isAssignmentOption(item)) {
            const eq_index = std.mem.indexOf(u8, item, "=") orelse unreachable;
            const flagname = item[0..eq_index];
            const value = item[(eq_index + 1)..];
            return Pair{ .name = flagname, .value = value };
        }

        const possibleValue = self.args.next() orelse return Pair{ .name = item, .value = null };
        if (isOption(possibleValue)) {
            self.prev = possibleValue;
            return Pair{ .name = item, .value = null };
        }
        return Pair{ .name = item, .value = possibleValue };
    }

    pub fn deinit(self: *Self) void {
        self.args.deinit();
    }
};
