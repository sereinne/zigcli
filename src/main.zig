const std = @import("std");
const zigcli = @import("zigcli");
const print = std.debug.print;

// define your CLI app here
const Command = struct {
    // all of these field in this struct fill be treated as options or flags
    // you can also add default values. For now, if one or more fields doesn't have a default value,
    // `zigcli` will treat all values as undefined.
    help: bool = true,
    version: bool = true,
    message: []const u8 = "echo...",
};

pub fn main() !void {
    var cli_app = zigcli.CLIApp(Command, void, .{}).default();
    const inner = cli_app.getInner();
    // initial flag value message (echo...)
    print("{s}\n", .{inner.message});
    // user invokes a flag `--message=hello`
    try cli_app.parse();
    // do something with the flags
    // this prints the new value (hello)
    print("{s}\n", .{inner.message});
}
