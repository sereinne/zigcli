const std = @import("std");
const argparser = @import("argparser");
const ArgumentParserFromSlice = argparser.ArgumentParserFromSlice;
const assert = std.debug.assert;
const eql = std.mem.eql;

test "parse assignment flag" {
    const args = &.{ "--foo=10", "--bar=20", "--baz=30" };
    var apfs = ArgumentParserFromSlice.init(args);
    var pair = apfs.next().?;
    assert(eql(u8, pair.name, "--foo"));
    assert(eql(u8, pair.value.?, "10"));
    pair = apfs.next().?;
    assert(eql(u8, pair.name, "--bar"));
    assert(eql(u8, pair.value.?, "20"));
    pair = apfs.next().?;
    assert(eql(u8, pair.name, "--baz"));
    assert(eql(u8, pair.value.?, "30"));
}

test "parse paired flag" {
    const args = &.{ "--foo", "10", "--bar", "20", "--baz", "30" };
    var apfs = ArgumentParserFromSlice.init(args);
    var pair = apfs.next().?;
    assert(eql(u8, pair.name, "--foo"));
    assert(eql(u8, pair.value.?, "10"));
    pair = apfs.next().?;
    assert(eql(u8, pair.name, "--bar"));
    assert(eql(u8, pair.value.?, "20"));
    pair = apfs.next().?;
    assert(eql(u8, pair.name, "--baz"));
    assert(eql(u8, pair.value.?, "30"));
}

test "parse trailing flag" {
    const args = &.{ "--foo", "--bar", "--baz" };
    var apfs = ArgumentParserFromSlice.init(args);
    var pair = apfs.next().?;
    assert(eql(u8, pair.name, "--foo"));
    assert(pair.value == null);
    pair = apfs.next().?;
    assert(eql(u8, pair.name, "--bar"));
    assert(pair.value == null);
    pair = apfs.next().?;
    assert(eql(u8, pair.name, "--baz"));
    assert(pair.value == null);
}

test "parse mixed (assignment, paired and trailing) flags" {
    const args = &.{ "--foo", "--bar", "10", "--baz=20" };
    var apfs = ArgumentParserFromSlice.init(args);
    var pair = apfs.next().?;
    assert(eql(u8, pair.name, "--foo"));
    assert(pair.value == null);
    pair = apfs.next().?;
    assert(eql(u8, pair.name, "--bar"));
    assert(eql(u8, pair.value.?, "10"));
    pair = apfs.next().?;
    assert(eql(u8, pair.name, "--baz"));
    assert(eql(u8, pair.value.?, "20"));
}

test "parse mixed (assignment, paired and trailing) flags v2" {
    const args = &.{ "--foo", "--bar", "--baz", "20" };
    var apfs = ArgumentParserFromSlice.init(args);
    var pair = apfs.next().?;
    assert(eql(u8, pair.name, "--foo"));
    assert(pair.value == null);
    pair = apfs.next().?;
    assert(eql(u8, pair.name, "--bar"));
    assert(pair.value == null);
    pair = apfs.next().?;
    assert(eql(u8, pair.name, "--baz"));
    assert(eql(u8, pair.value.?, "20"));
}

test "parse mixed (assignment, paired and trailing) flags v3" {
    const args = &.{ "--foo", "--bar", "20", "--baz" };
    var apfs = ArgumentParserFromSlice.init(args);
    var pair = apfs.next().?;
    assert(eql(u8, pair.name, "--foo"));
    assert(pair.value == null);
    pair = apfs.next().?;
    assert(eql(u8, pair.name, "--bar"));
    assert(eql(u8, pair.value.?, "20"));
    pair = apfs.next().?;
    assert(eql(u8, pair.name, "--baz"));
    assert(pair.value == null);
}
