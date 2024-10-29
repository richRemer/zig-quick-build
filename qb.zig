const std = @import("std");
const Type = std.builtin.Type;

/// Initialize a build based on build spec.
pub fn QuickBuild(comptime spec: anytype) type {
    return struct {
        /// Build context.
        pub const Context = struct {
            build: *std.Build,
            deps: Dependencies(spec),
            target: std.Build.ResolvedTarget,
            optimize: std.builtin.OptimizeMode,

            pub fn init(b: *std.Build) Context {
                log.debug("b.standardTargetOptions(.{{}})", .{});
                log.debug("b.standardOptimizeOption(.{{}})", .{});

                return .{
                    .build = b,
                    .deps = .{},
                    .target = b.standardTargetOptions(.{}),
                    .optimize = b.standardOptimizeOption(.{}),
                };
            }
        };

        /// Setup a build based on the build spec.
        pub fn setup(b: *std.Build) !void {
            var context = Context.init(b);
            const Spec = @TypeOf(spec);

            log.debug("test_step = b.step(\"test\", \"Run unit tests\")", .{});
            _ = b.step("test", "Run unit tests");

            inline for (@typeInfo(Dependencies(spec)).@"struct".fields) |f| {
                const name = f.name;

                log.debug("{s} = b.dependency(\"{s}\", .{{...}})", .{ name, name });
                @field(context.deps, name) = context.build.dependency(name, .{
                    .target = context.target,
                    .optimize = context.optimize,
                });
            }

            if (@hasField(Spec, "exes")) {
                try @This().setupArtifacts(.exe, spec.exes, &context);
            }

            if (@hasField(Spec, "libs")) {
                try @This().setupArtifacts(.lib, spec.libs, &context);
            }
        }

        /// Setup build artifacts based on the .exes or .libs spec.
        fn setupArtifacts(
            art_type: ArtifactType,
            arts_spec: anytype,
            context: *Context,
        ) !void {
            const Arts = @TypeOf(arts_spec);
            const arts_info = @typeInfo(Arts);

            inline for (arts_info.@"struct".fields) |f| {
                const name = f.name;
                const art_spec = @field(arts_spec, name);
                try @This().setupArtifact(art_type, name, art_spec, context);
            }
        }

        /// Setup an artifact from spec found in .exes or .libs.
        fn setupArtifact(
            art_type: ArtifactType,
            name: []const u8,
            art_spec: anytype,
            context: *Context,
        ) !void {
            var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
            defer arena.deinit();

            const Art = @TypeOf(art_spec);
            const allocator = arena.allocator();
            const src_fmt = "{s}/{s}.zig";
            const root_source_file = context.build.path(
                try std.fmt.allocPrint(allocator, src_fmt, .{
                    spec.src_path,
                    name,
                }),
            );

            switch (art_type) {
                .exe => log.debug(
                    "artifact = b.addExecutable(.{{.name=\"{s}\", .root_source_file=\"{s}\", ...}})",
                    .{ name, root_source_file.src_path.sub_path },
                ),
                .lib => log.debug(
                    "artifact = b.addStaticLibrary(.{{.name=\"{s}\", .root_source_file=\"{s}\", ...}})",
                    .{ name, root_source_file.src_path.sub_path },
                ),
            }

            const art = switch (art_type) {
                .exe => context.build.addExecutable(.{
                    .name = name,
                    .root_source_file = root_source_file,
                    .target = context.target,
                    .optimize = context.optimize,
                }),
                .lib => context.build.addStaticLibrary(.{
                    .name = name,
                    .root_source_file = root_source_file,
                    .target = context.target,
                    .optimize = context.optimize,
                }),
            };

            if (@hasField(Art, "sys")) {
                log.debug("artifact.linkLibC()");
                art.linkLibC();
                @This().setupSysLinks(art, art_spec.sys);
            }

            if (@hasField(Art, "zig")) {
                @This().setupZigImports(art, art_spec.zig, context);
            }

            log.debug("b.installArtifact(artifact)", .{});
            context.build.installArtifact(art);

            if (context.build.top_level_steps.get("test")) |test_step| {
                log.debug(
                    "artifact = b.addTest(.{{.root_source_file=\"{s}\", ...}})",
                    .{root_source_file.src_path.sub_path},
                );
                const test_art = context.build.addTest(.{
                    .root_source_file = root_source_file,
                    .target = context.target,
                    .optimize = context.optimize,
                });

                log.debug("run_test = b.addRunArtifact(artifact)", .{});
                const run_test = context.build.addRunArtifact(test_art);

                if (@hasField(Art, "sys")) {
                    log.debug("artifact.linkLibC()");
                    test_art.linkLibC();
                    @This().setupSysLinks(test_art, art_spec.sys);
                }

                if (@hasField(Art, "zig")) {
                    @This().setupZigImports(test_art, art_spec.zig, context);
                }

                log.debug("test_step.step.dependOn(&run_test.step)", .{});
                test_step.step.dependOn(&run_test.step);
            }
        }

        /// Setup build system library links based on build .sys spec.
        fn setupSysLinks(
            artifact: *std.Build.Step.Compile,
            sys_spec: anytype,
        ) void {
            const sys_info = @typeInfo(@TypeOf(sys_spec));

            inline for (sys_info.@"struct".fields) |link| {
                const name = @tagName(@field(sys_spec, link.name));
                log.debug("artifact.linkSystemLibrary(\"{s}\")", .{name});
                artifact.linkSystemLibrary(name);
            }
        }

        /// Setup Zig imports for an artifact based on build .zig spec.
        fn setupZigImports(
            artifact: *std.Build.Step.Compile,
            zig_spec: anytype,
            context: *Context,
        ) void {
            const zig_info = @typeInfo(@TypeOf(zig_spec));

            inline for (zig_info.@"struct".fields) |import| {
                const name = @tagName(@field(zig_spec, import.name));
                const dep = @field(context.deps, name).?;

                log.debug(
                    "artifact.root_module.addImport(\"{s}\", {s}.module(\"{s}\"))",
                    .{ name, name, name },
                );
                artifact.root_module.addImport(name, dep.module(name));
            }
        }
    };
}

/// Type of artifact being produced.
const ArtifactType = enum {
    exe,
    lib,
};

/// Builder for set of dependencies based on build spec.
fn Dependencies(comptime spec: anytype) type {
    const Spec = @TypeOf(spec);
    const Deps = if (@hasField(Spec, "deps")) @TypeOf(spec.deps) else void;
    const deps_info = @typeInfo(Deps);
    const deps_len = if (Deps != void) deps_info.@"struct".fields.len else 0;

    comptime var fields: [deps_len]Type.StructField = undefined;

    if (deps_len > 0) {
        const nul = @typeInfo(Null(*std.Build.Dependency)).@"struct".fields[0].default_value;

        inline for (deps_info.@"struct".fields, 0..) |field, i| {
            const tag = @field(spec.deps, field.name);

            fields[i] = Type.StructField{
                .name = @tagName(tag),
                .type = ?*std.Build.Dependency,
                .alignment = @alignOf(?*std.Build.Dependency),
                .default_value = nul,
                .is_comptime = false,
            };
        }
    }

    return @Type(Type{
        .@"struct" = Type.Struct{
            .layout = .auto,
            .is_tuple = false,
            .fields = &fields,
            .decls = &[0]Type.Declaration{},
        },
    });
}

/// This piece of hackery is used to lookup a comptime *const anyopaque that
/// can be used to define StructField with a null default_value.
///
/// In order to obtain the value:
/// @typeInfo(Null(T)).@"struct".fields[0].default_value
fn Null(comptime T: type) type {
    return struct { value: ?T = null };
}

/// Scoped log.
const log = std.log.scoped(.qb);
