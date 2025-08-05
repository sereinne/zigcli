const std = @import("std");
const rootlib = @import("rootlib");
const expect = std.testing.expect;
const eql = std.mem.eql;
const hasDefaultFieldValue = rootlib.hasDefaultFieldValue;
const defaultOrNull = rootlib.defaultOrNull;
const isSubcommandStruct = rootlib.isSubcommandStruct;
const getSubcommand = rootlib.getSubcommand;
const isAssignmentOption = rootlib.isAssignmentOption;
const isLongOption = rootlib.isLongOption;
const isRegisteredSubcommand = rootlib.isRegisteredSubcommand;

const Info = struct {
    name: ?[]const u8 = null,
    value: ?[]const u8 = null,
    previous: ?[]const u8 = null,
    args: ?[]const u8 = null,
    scope: ?[]const u8 = null,
};

test "hasDefaultFields function" {
    const Foo = struct {
        foo: i32,
    };
    try expect(hasDefaultFieldValue(Foo) == false);

    const Bar = struct {
        bar: i32 = 0,
    };
    try expect(hasDefaultFieldValue(Bar) == true);

    const BazEmpty = struct {
        bar: i32,
        bah: i32,
    };
    try expect(hasDefaultFieldValue(BazEmpty) == false);

    const BazDefault = struct {
        bar: i32 = 0,
        bah: i32 = 1,
    };
    try expect(hasDefaultFieldValue(BazDefault) == true);
}

test "defaultOrNull function" {
    const Foo = struct {
        foo: i32,
    };
    const uninit = defaultOrNull(Foo);
    try expect(uninit == null);

    const Bar = struct {
        bar: i32 = 0,
    };
    const withDefault = defaultOrNull(Bar);
    const default = Bar{};
    try expect(withDefault.?.bar == default.bar);
}

test "isSubcommand function" {
    const Main = struct {
        pub const docs = true;
    };

    try expect(isSubcommandStruct(Main));

    const Second = struct {
        foo: i32,
    };

    try expect(!isSubcommandStruct(Second));
}

test "getSubcommand function" {
    const Main = struct { foo: struct {
        pub const docs = true;
    }, bar: struct {
        pub const docs = true;
    }, baz: struct {
        pub const docs = true;
    } };

    const subcmds = getSubcommand(Main);
    try expect(eql(u8, subcmds[0], "foo"));
    try expect(eql(u8, subcmds[1], "bar"));
    try expect(eql(u8, subcmds[2], "baz"));
}

const Iter = struct {
    const Self = @This();

    prev: ?[]const u8 = null,
    args: []const []const u8,
    idx: usize = 0,
    result: Info = Info{},
    subcommands: []const []const u8,

    pub fn new(args: []const []const u8, subcmds: []const []const u8) Self {
        return .{
            .args = args,
            .subcommands = subcmds,
        };
    }

    pub fn next_arg(self: *Self) ?[]const u8 {
        if (self.idx == self.args.len) {
            return null;
        }

        const tmp = self.args[self.idx];
        self.idx += 1;
        return tmp;
    }

    fn handleLongOption(self: *Self, optname: []const u8) void {
        if (isAssignmentOption(optname)) {
            const idx = std.mem.indexOf(u8, optname, "=").?;
            const key = optname[0..idx];
            const value = optname[(idx + 1)..];
            self.result.name = key;
            self.result.value = value;
            return;
        }

        const value = self.next_arg() orelse {
            self.result.name = optname;
            return;
        };

        if (isLongOption(value)) {
            self.prev = value;
            self.result.name = optname;
            self.result.previous = value;
            self.result.value = null;
            return;
        }

        if (isRegisteredSubcommand(self.subcommands, value)) {
            self.prev = null;
            self.result.name = optname;
            self.result.value = null;
            self.result.scope = value;
            self.result.previous = null;
            return;
        }

        self.result.name = optname;
        self.result.value = value;
        self.result.previous = null;
        return;
    }

    pub fn next(self: *Self) ?void {
        while (self.next_arg()) |arg| {
            if (self.prev) |prev| {
                if (isLongOption(prev)) {
                    if (isLongOption(arg)) {
                        self.result.name = prev;
                        self.result.value = null;
                        self.result.previous = arg;
                        self.prev = arg;
                        return;
                    }

                    if (isRegisteredSubcommand(subcommands, arg)) {
                        self.prev = null;
                        self.result.name = prev;
                        self.result.value = null;
                        self.result.previous = null;
                        self.result.scope = arg;
                        return;
                    }
                }
            }
            if (isLongOption(arg)) {
                self.handleLongOption(arg);
                return;
            }
        }

        if (self.prev) |prev| {
            if (isLongOption(prev)) {
                self.result.name = prev;
                self.result.value = null;
                self.result.previous = null;
                self.prev = null;
                return;
            }
        }
        return null;
    }
};

const subcommands = &.{ "diff", "commit", "add" };

test "parse assignment flags" {
    const args = &.{ "--foo=10", "--bar=20", "--baz=30" };
    var iter = Iter.new(args, subcommands);
    iter.next().?;
    try expect(eql(u8, iter.result.name.?, "--foo"));
    try expect(eql(u8, iter.result.value.?, "10"));
    iter.next().?;
    try expect(eql(u8, iter.result.name.?, "--bar"));
    try expect(eql(u8, iter.result.value.?, "20"));
    iter.next().?;
    try expect(eql(u8, iter.result.name.?, "--baz"));
    try expect(eql(u8, iter.result.value.?, "30"));
    try expect(iter.next() == null);
}

test "parse ending flag" {
    const args = &.{"--foo"};
    var iter = Iter.new(args, subcommands);
    iter.next().?;
    try expect(eql(u8, iter.result.name.?, "--foo"));
    try expect(iter.next() == null);
}

test "parse paired flags" {
    const args = &.{ "--foo", "10", "--bar", "20", "--baz", "30" };
    var iter = Iter.new(args, subcommands);
    iter.next().?;
    try expect(eql(u8, iter.result.name.?, "--foo"));
    try expect(eql(u8, iter.result.value.?, "10"));
    iter.next().?;
    try expect(eql(u8, iter.result.name.?, "--bar"));
    try expect(eql(u8, iter.result.value.?, "20"));
    iter.next().?;
    try expect(eql(u8, iter.result.name.?, "--baz"));
    try expect(eql(u8, iter.result.value.?, "30"));
    try expect(iter.next() == null);
}

test "parse trailing flags" {
    const args = &.{ "--foo", "--bar" };
    var iter = Iter.new(args, subcommands);
    iter.next().?;
    try expect(eql(u8, iter.result.name.?, "--foo"));
    try expect(iter.result.value == null);
    try expect(eql(u8, iter.result.previous.?, "--bar"));
    iter.next().?;
    try expect(eql(u8, iter.result.name.?, "--bar"));
    try expect(iter.result.value == null);
    try expect(iter.result.previous == null);
    try expect(iter.next() == null);
}

test "parse trailing flags v2" {
    const args = &.{ "--foo", "--bar", "--baz" };
    var iter = Iter.new(args, subcommands);
    iter.next().?;
    try expect(eql(u8, iter.result.name.?, "--foo"));
    try expect(iter.result.value == null);
    try expect(eql(u8, iter.result.previous.?, "--bar"));
    iter.next().?;
    try expect(eql(u8, iter.result.name.?, "--bar"));
    try expect(iter.result.value == null);
    try expect(eql(u8, iter.result.previous.?, "--baz"));
    iter.next().?;
    try expect(eql(u8, iter.result.name.?, "--baz"));
    try expect(iter.result.value == null);
    try expect(iter.result.previous == null);
    try expect(iter.next() == null);
}

test "parse mixed flags" {
    const args = &.{ "--foo=10", "--bar", "--baz" };
    var iter = Iter.new(args, subcommands);
    iter.next().?;
    try expect(eql(u8, iter.result.name.?, "--foo"));
    try expect(eql(u8, iter.result.value.?, "10"));
    try expect(iter.result.previous == null);
    iter.next().?;
    try expect(eql(u8, iter.result.name.?, "--bar"));
    try expect(iter.result.value == null);
    try expect(eql(u8, iter.result.previous.?, "--baz"));
    iter.next().?;
    try expect(eql(u8, iter.result.name.?, "--baz"));
    try expect(iter.result.value == null);
    try expect(iter.result.previous == null);
    try expect(iter.next() == null);
}

test "parse subcommands" {
    const args = &.{ "--foo=10", "--bar", "diff" };
    var iter = Iter.new(args, subcommands);
    iter.next().?;
    try expect(eql(u8, iter.result.name.?, "--foo"));
    try expect(eql(u8, iter.result.value.?, "10"));
    try expect(iter.result.previous == null);
    iter.next().?;
    try expect(eql(u8, iter.result.name.?, "--bar"));
    try expect(iter.result.value == null);
    try expect(iter.result.previous == null);
    try expect(eql(u8, iter.result.scope.?, "diff"));
}

test "parse subcommands v2" {
    const args = &.{ "--foo", "--bar", "diff" };
    var iter = Iter.new(args, subcommands);
    iter.next().?;
    try expect(eql(u8, iter.result.name.?, "--foo"));
    try expect(iter.result.value == null);
    try expect(eql(u8, iter.result.previous.?, "--bar"));
    iter.next().?;
    try expect(eql(u8, iter.result.name.?, "--bar"));
    try expect(iter.result.value == null);
    try expect(iter.result.previous == null);
    try expect(eql(u8, iter.result.scope.?, "diff"));
}

test "example user cli" {
    const args = &.{ "--pager", "diff", "--staged", "--status" };
    var iter = Iter.new(args, subcommands);
    iter.next().?;
    try expect(eql(u8, iter.result.name.?, "--pager"));
    try expect(iter.result.value == null);
    try expect(eql(u8, iter.result.scope.?, "diff"));
    iter.next().?;
    try expect(eql(u8, iter.result.name.?, "--staged"));
    try expect(iter.result.value == null);
    try expect(eql(u8, iter.result.scope.?, "diff"));
    iter.next().?;
    try expect(eql(u8, iter.result.name.?, "--status"));
    try expect(iter.result.value == null);
    try expect(eql(u8, iter.result.scope.?, "diff"));
}

test "example user cli v2" {
    const args = &.{ "--pager", "--status", "diff", "--staged", "--status" };
    var iter = Iter.new(args, subcommands);
    iter.next().?;
    try expect(eql(u8, iter.result.name.?, "--pager"));
    try expect(iter.result.value == null);
    try expect(eql(u8, iter.result.previous.?, "--status"));
    iter.next().?;
    try expect(eql(u8, iter.result.name.?, "--status"));
    try expect(iter.result.value == null);
    try expect(eql(u8, iter.result.scope.?, "diff"));
    try expect(iter.result.previous == null);
    iter.next().?;
    try expect(eql(u8, iter.result.name.?, "--staged"));
    try expect(iter.result.value == null);
    try expect(eql(u8, iter.result.scope.?, "diff"));
    try expect(eql(u8, iter.result.previous.?, "--status"));
    iter.next().?;
    try expect(eql(u8, iter.result.name.?, "--status"));
    try expect(iter.result.value == null);
    try expect(eql(u8, iter.result.scope.?, "diff"));
    try expect(iter.result.previous == null);
}
