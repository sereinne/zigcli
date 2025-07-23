// module import
const std = @import("std");
// function imports
const parseInt = std.fmt.parseInt;
const parseFloat = std.fmt.parseFloat;
const eql = std.mem.eql;
pub fn Parser(comptime T: type) type {
    return *const fn ([]const u8) anyerror!T;
}

// string transformation from into another type
pub fn parseWithFallback(comptime Priority: type, comptime Fallback: type, item: []const u8, fallback: ?Parser(Fallback)) !Priority {
    const info = @typeInfo(Priority);
    return switch (info) {
        .bool => try parseToBool(item),
        .int => try parseInt(Priority, item, 10),
        .float => try parseFloat(Priority, item),
        .pointer => |pinfo| {
            if (pinfo.child == u8 and pinfo.is_const and pinfo.alignment == 1 and pinfo.size == .slice) {
                return item;
            }
            @compileError("ERROR: unsupported pointer type, only supports strings which is `[]const u8`");
        },
        else => {
            if (Priority == Fallback) {
                if (fallback) |fallbackfn| {
                    return fallbackfn(item);
                } else {
                    // its important to return an `error` rather than `@compileError` because the fallback value is known at runtime,
                    // but `@compileError` run first because its a builtin function that runs at compile time.
                    return error.NoFallbackType;
                }
            }
            @compileError("mismatched fallback type");
        },
    };
}

fn parseToBool(item: []const u8) !bool {
    if (eql(u8, item, "true")) {
        return true;
    } else if (eql(u8, item, "false")) {
        return false;
    }
    return error.parseBooleanError;
}
