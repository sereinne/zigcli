# Zigcli

A library to create CLI apps easily in `zig`

# Foreword

The goal of `zigcli` is to create APIs and features similar to [`clap`](https://github.com/clap-rs/clap) such as:


| feature                 | status |
| ----------------------- | ------ |
| reasonable flag parsing |   ✅   |
| create subcommands      |   ⚠️   |
| generate help message   |   ⚠️   |
| shell completions       |   ❌   |
| suggestion fixes        |   ❌   |


> [!Note]
> ✅: implemented
> ⚠️: unimplemented (work in progess)
> ❌: unimpleented (needs consideration in the future)

# Usage


```zig
const std = @import("std");
const zigcli = @import("zigcli");

// define your CLI app here
const Command = struct {
    // all of these field in this struct fill be treated as options or flags
    // you can also add default values. For now, if one or more fields doesn't have a default value,
    // `zigcli` will treat all values as undefined.
    // `zigcli will catch and modify these field if `--help`, `--version` and `--message` are present in the command line
    help: bool = true,
    version: bool = true,
    message: []const u8 = "foo",
};

pub fn main() !void {
    // initialize CLI application maker. 
    var cli_app = zigcli.CLIApp(Command, void, .{}).default();
    // get the inner value `Command`
    const inner = cli_app.getInner();
    // initial flag value message (foo)
    std.debug.print("{s}\n", .{inner.message});
    // user invokes a flag `--message=bar` or you can use quotes `--message="bar"`
    try cli_app.parse();
    // do something with the flags
    // this prints the new value (bar)
    std.debug.print("{s}\n", .{inner.message});
}
```

# Installation

To use this library, you can use `zig fetch --save` to add this into your `build.zig.zon` file.

```sh
$ zig fetch --save "git+https://github.com/sereinne/zigcli"
```


