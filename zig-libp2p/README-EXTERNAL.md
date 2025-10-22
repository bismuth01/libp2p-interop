Using zig-libp2p as an external dependency
========================================

This repository includes `build_external_libp2p.zig` — a small helper that lets
consumer Zig projects pull in `zig-libp2p` at build time without vendoring the
entire repository.

How it works
------------
- At configure time the helper will clone `https://github.com/libp2p/zig-libp2p.git`
  into `zig-cache/libp2p-src` (by default). You can override the URL with
  the environment variable `ZIG_LIBP2P_URL` and the branch/ref with
  `ZIG_LIBP2P_REF`.
- It registers `msquic`, `libp2p-msquic` and `libp2p` as `std.build.Pkg`s which
  you can add to your build steps.

Usage example (in your project's `build.zig`):

const std = @import("std");

pub fn build(b: *std.build.Builder) !void {
    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const exe = b.addExecutable("my-app", "src/main.zig");
    exe.setBuildMode(mode);
    exe.setTarget(target);

    // Load helper (adjust path if you copied the file into your repo)
    const external = try std.build.loadModule("build_external_libp2p.zig");
    // Add external packages into the executable step
    try external.addExternalLibp2pPackages(allocator, exe, mode);

    const run_step = b.step("run", "Build and run");
    run_step.dependOn(&exe.run().step);
}

Notes
-----
- `git` must be available on PATH during configure.
- The helper clones into `zig-cache/libp2p-src` relative to your project root.
- If you prefer to vendor the library, point `ZIG_LIBP2P_URL` to a local path
  or copy the `src` directory into your project and register packages manually.
