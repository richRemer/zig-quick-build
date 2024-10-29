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
        // (optional) executables to generate from the build
        .exes = .{
            // set the key to the executable name
            .FOO = .{
                // (optional) setup static link to system C library
                .sys = .{.LIBFOO, .LIBBAR},
                // (optional) setup imported module from dependency
                .zig = .{.DEPENDENCY},
            },
            // ... additional executables ...
        },
        // (optional) static libraries to generate from the build
        .libs = .{
            // set the key to the library name
            .FOO = .{
                // (optional) setup static link to system C library
                .sys = .{.LIBFOO, .LIBBAR},
                // (optional) setup imported module from dependency
                .zig = .{.DEPENDENCY},
            },
        },
    }).setup(b);
}
```
