Zig QuickBuild module to quickly setup simple builds.

Installing
==========
The recommended way to install the QuickBuild module (**qb.zig**) is to simple
copy it into your project directory.

```sh
$ wget https://raw.githubusercontent.com/richRemer/zig-qb/master/qb.zig
```

Usage
=====
To use the QuickBuild module, replace your standard **build.zig** file with
something like the following:

```zig
const std = @import("std");
const QuickBuild = @import("qb.zig").QuickBuild;

pub fn build(b: *std.Build) !void {
    try QuickBuild(.{
        // (required) path where source files are found
        .src_path = "src",
        // (optional) describe any Zig module dependencies to use
        .deps = .{.DEPENDENCY},
        // (required) build outputs
        .outs = .{
            // set key to name
            .FOO = .{
                // (optional) statically link artifacts to system C libraries
                .sys = .{.LIBRARYA, .LIBRARYB},
                // (optional) add module dependencies to outputs
                .zig = .{.DEPENDENCY},
                // (required) types of build output to generate
                .gen = .{
                    // (optional) build executable
                    .exe,
                    // (optional) build static library
                    .lib,
                    // (optional) export Zig module
                    .mod,
                    // (optional) add module to test suite
                    .unit,
                }
            },
            // ... additional outputs ...
        },
    }).setup(b);
}
```
