const std = @import("std");
const parseInt = std.fmt.parseInt;
const parseFloat = std.fmt.parseFloat;
const eql = std.mem.eql;

pub fn parseDefault(comptime T: type, s: []const u8) !T {
    const info = @typeInfo(T);
    return switch (info) {
        .bool => {
            if (eql(u8, s, "true")) {
                return true;
            } else if (eql(u8, s, "false")) {
                return false;
            }
            return error.ParseBooleanError;
        },
        .int => return try parseInt(T, s, 10),
        .float => return try parseFloat(T, s),
        .pointer => |pinfo| {
            if (pinfo.child == u8 and pinfo.is_const and pinfo.size == .slice) {
                return s;
            }
            return error.UnsupportedPointerType;
        },
        else => return error.UnimplementedType,
    };
}
