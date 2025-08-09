# Zigcli

A library to create CLI apps easily in `zig`

# Foreword

The goal of `zigcli` is to create APIs and features similar to [`clap`](https://github.com/clap-rs/clap) such as:


| feature                 | status |
| ----------------------- | ------ |
| reasonable flag parsing |    ✅  |
| create subcommands      |    ✅  |
| generate help message   |   ⚠️   |
| shell completions       |   ❌   |
| suggestion fixes        |   ❌   |


> [!Note]
> ✅: implemented
> ⚠️: unimplemented (work in progess)
> ❌: unimpleented (needs consideration in the future)

# Usage


```zig
// define your CLI app template
// note that the main-command and each subcommands must have a declaration called `docs`
// for now, `docs` is marked just as an identifier for `zigcli` to distinguish between a internal `struct` or a subcommand 
const Git = struct {
    pub const docs = true;
    // ... other flags omitted
    @"no-pager": bool,
    // place to store arguments.
    args: std.ArrayList([]const u8),
    diff: struct {
        pub const docs = true;
        // ... other flags omitted
        staged: i32,
        // place to store `diff`'s arguments.
        args: std.ArrayList([]const u8),
    },
    branch: struct {
        pub const docs = true;
        // ... other flags omitted
        list: i32,
        // place to store `branch`'s arguments.
        args: std.ArrayList([]const u8),
    },
};

pub fn main() !void {
    // choose your allocator. For now, `zigcli` doesn't have a `default` method that allocates the `Allocator type` inside the constructor which causes
    // undefined behaviour
    var dbg_alloc = std.heap.DebugAllocator(.{}){};
    const allocator = dbg_alloc.allocator();
    // initialize your CLI app. keep in mind that your app, in this case `Git`, is initialized with all of its field to `undefined`.
    var cli = rootlib.CreateApp(Git).init(allocator);
    // deinitializes allocated memory 
    defer cli.deinit();

    // the conditions of your CLI flags before the parsing phase.
    print("BEFORE:\n", .{});
    print("no-pager: {}\n", .{cli.inner.@"no-pager"});
    print("diff.staged: {}\n", .{cli.inner.diff.staged});
    print("branch.list: {}\n", .{cli.inner.branch.list});
    try cli.parse();
    // the conditions of your CLI flags and arguments after the parsing phase. 
    // you might do something with the flags after parsing.
    print("AFTER:\n", .{});
    print("no-pager: {}\n", .{cli.inner.@"no-pager"});
    print("diff.staged: {}\n", .{cli.inner.diff.staged});
    print("branch.list: {}\n", .{cli.inner.branch.list});

    for (cli.inner.args.items) |item| {
        print("main command's argument: {s}\n", .{item});
    }

    for (cli.inner.diff.args.items) |item| {
        print("diff's subcommand argument: {s}\n", .{item});
    }

    for (cli.inner.branch.args.items) |item| {
        print("branch's subcommand argument: {s}\n", .{item});
    }
}
```

# Installation

To use this library, you can use `zig fetch --save` to add this into your `build.zig.zon` file.

```sh
$ zig fetch --save "git+https://github.com/sereinne/zigcli"
```


