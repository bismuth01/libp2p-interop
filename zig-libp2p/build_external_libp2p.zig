const std = @import("std");

/// Helper for consumer projects to import zig-libp2p without vendoring the source.
///
/// Usage from your project's build.zig:
///   const external = try std.build.loadModule("build_external_libp2p.zig");
///   try external.addExternalLibp2pPackages(b, allocator, &step, mode, target);
///
/// It will clone the repository (by default from GitHub) into zig-cache/libp2p-src
/// at configure time and then register the relevant packages (libp2p, msquic,
/// libp2p-msquic) so you can add them to your executable or test steps.
pub const ExternalError = error{ CloneFailed, PathJoinFailed, SpawnFailed, WaitFailed };

pub fn addExternalLibp2pPackages(allocator: std.mem.Allocator, step: *std.build.LibExeObjStep, mode: std.builtin.Mode) anyerror!void {
    var env = try std.process.getEnvMap(allocator);

    const repo_url = env.get("ZIG_LIBP2P_URL") orelse "https://github.com/libp2p/zig-libp2p.git";
    const checkout_ref = env.get("ZIG_LIBP2P_REF") orelse "main";

    // Determine a cache directory under zig-cache in the project
    // Use a relative path under the project root; calling .path() on fs.Dir isn't
    // supported. Keep it simple and use a local relative path so the helper works
    // from the project root.
    const cache_dir_path = try std.fs.path.join(allocator, &.{ ".", "zig-cache", "libp2p-src" });
    defer allocator.free(cache_dir_path);

    // If directory doesn't exist, run `git clone --depth 1 --branch <ref> <url> <dir>`
    const dir_open = std.fs.cwd().openDir(cache_dir_path, .{});
    if (dir_open) |dir| {
        // already cloned
        try dir.close();
    } else {
        const cmd = &[_][]const u8{ "git", "clone", "--depth", "1", "--branch", checkout_ref, repo_url, cache_dir_path };
        var child = try std.ChildProcess.spawn(cmd, null) catch return ExternalError.SpawnFailed;
        defer child.deinit();
        const exit = try child.wait() catch return ExternalError.WaitFailed;
        if (exit != 0) return ExternalError.CloneFailed;
    }

    // Add packages pointing into the cache
    const msquic_path = std.fs.path.join(allocator, &.{ cache_dir_path, "zig-msquic", "src", "msquic.zig" }) catch return ExternalError.PathJoinFailed;
    defer allocator.free(msquic_path);

    const libp2p_path = std.fs.path.join(allocator, &.{ cache_dir_path, "src", "libp2p.zig" }) catch return ExternalError.PathJoinFailed;
    defer allocator.free(libp2p_path);

    const libp2p_msquic_path = std.fs.path.join(allocator, &.{ cache_dir_path, "src", "msquic.zig" }) catch return ExternalError.PathJoinFailed;
    defer allocator.free(libp2p_msquic_path);

    step.addPackage(std.build.Pkg{
        .name = "msquic",
        .source = .{ .path = msquic_path },
    });
    step.addPackage(std.build.Pkg{ .name = "libp2p-msquic", .source = .{ .path = libp2p_msquic_path }, .dependencies = &[_]std.build.Pkg{.{ .name = "msquic", .source = .{ .path = msquic_path } }} });
    step.addPackage(std.build.Pkg{ .name = "libp2p", .source = .{ .path = libp2p_path }, .dependencies = &[_]std.build.Pkg{ .{ .name = "libp2p-msquic", .source = .{ .path = libp2p_msquic_path }, .dependencies = &[_]std.build.Pkg{.{ .name = "msquic", .source = .{ .path = msquic_path } }} }, .{ .name = "msquic", .source = .{ .path = msquic_path } } } });

    step.setBuildMode(mode);
}
