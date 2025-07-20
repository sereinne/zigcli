const std = @import("std");
const zigcli = @import("zigcli");
const assert = std.debug.assert;

test "foo" {
    const result = zigcli.addNum(1, 2);
    assert(result == 3);
}
