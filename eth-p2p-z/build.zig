const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const log_level_opt = b.option([]const u8, "log-level", "Set std.log level (debug, info, warn, err)");

    const build_options = b.addOptions();
    build_options.addOption(?[]const u8, "log_level", log_level_opt);

    const zmultiformats_dep = b.dependency("zmultiformats", .{
        .target = target,
        .optimize = optimize,
    });
    const zmultiformats_module = zmultiformats_dep.module("multiformats-zig");

    const peer_id_dep = zmultiformats_dep.builder.dependency("peer_id", .{
        .target = target,
        .optimize = optimize,
    });
    const peer_id_module = peer_id_dep.module("peer-id");

    const libp2p_dep = b.dependency("libp2p", .{
        .target = target,
        .optimize = optimize,
    });
    const libp2p_module = libp2p_dep.module("zig-libp2p");

    const ping_exe = b.addExecutable(.{
        .name = "ping",
        .root_source_file = b.path("ping/ping.zig"),
        .target = target,
        .optimize = optimize,
    });

    ping_exe.root_module.addImport("zig-libp2p", libp2p_module);
    ping_exe.root_module.addImport("multiformats", zmultiformats_module);
    ping_exe.root_module.addImport("peer_id", peer_id_module);
    ping_exe.root_module.addOptions("build_options", build_options);
    b.installArtifact(ping_exe);

    const ping_run_cmd = b.addRunArtifact(ping_exe);
    ping_run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        ping_run_cmd.addArgs(args);
    }
    const transport_interop_step = b.step("ping", "Run the ping binary");
    transport_interop_step.dependOn(&ping_run_cmd.step);
}
