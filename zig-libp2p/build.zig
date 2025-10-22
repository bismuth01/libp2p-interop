const std = @import("std");
const builtin = @import("builtin");
const external = @import("build_external_libp2p.zig");
const Allocator = std.mem.Allocator;

fn includeLibSystemFromNix(allocator: Allocator, l: anytype) anyerror!void {
    var vars = try std.process.getEnvMap(allocator);
    l.addIncludePath(vars.get("LIBSYSTEM_INCLUDE").?);
}

fn maybePatchElf(allocator: Allocator, b: *std.build.Builder, os: std.Target.Os.Tag, step: *std.build.Step, filename: []const u8) !*std.build.Step {
    const elf_interpreter = std.os.getenv("ELF_INTERPRETER") orelse "";
    if (os == .linux and (elf_interpreter).len > 0) {
        const path = try std.fmt.allocPrint(allocator, "./zig-out/bin/{s}", .{filename});
        defer allocator.free(path);
        const patchElf = b.addSystemCommand(&[_][]const u8{
            "patchelf",
            "--set-interpreter",
            elf_interpreter,
            path,
        });
        patchElf.step.dependOn(step);

        return &patchElf.step;
    } else {
        return step;
    }
}

pub fn addZigLibp2pPackages(allocator: Allocator, step: *std.build.LibExeObjStep, mode: std.builtin.Mode, target: std.zig.CrossTarget) anyerror!void {
    const msquic_builder = @import("./zig-msquic/build.zig");
    try msquic_builder.linkMsquic(allocator, target, step, true);
    try includeLibSystemFromNix(allocator, step);

    step.addPackage(std.build.Pkg{
        .name = "msquic",
        .source = .{
            .path = "zig-msquic/src/msquic.zig",
        },
    });

    step.addPackage(std.build.Pkg{ .name = "libp2p-msquic", .source = .{
        .path = "src/msquic.zig",
    }, .dependencies = &[_]std.build.Pkg{.{
        .name = "msquic",
        .source = .{
            .path = "zig-msquic/src/msquic.zig",
        },
    }} });
    step.addPackage(std.build.Pkg{
        .name = "libp2p",
        .source = .{
            .path = "src/libp2p.zig",
        },
        .dependencies = &[_]std.build.Pkg{ .{
            .name = "libp2p-msquic",
            .source = .{
                .path = "src/msquic.zig",
            },
            .dependencies = &[_]std.build.Pkg{.{
                .name = "msquic",
                .source = .{
                    .path = "zig-msquic/src/msquic.zig",
                },
            }},
        }, .{
            .name = "msquic",
            .source = .{
                .path = "zig-msquic/src/msquic.zig",
            },
        } },
    });

    step.setBuildMode(mode);
}

pub fn buildPingExample(b: *std.build.Builder, allocator: Allocator, mode: std.builtin.Mode, target: std.zig.CrossTarget) anyerror!void {
    const ping = b.addExecutable("ping", "ping/main.zig");
    ping.setTarget(target);
    ping.setBuildMode(mode);

    // Add packages and link
    try external.addExternalLibp2pPackages(allocator, ping, mode);

    const os = target.os_tag orelse builtin.os.tag;

    const ping_step = b.step("ping", "Build ping binary");
    ping_step.dependOn(try maybePatchElf(allocator, b, os, &b.addInstallArtifact(ping).step, ping.out_filename));
}

pub fn build(b: *std.build.Builder) anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});

    try buildPingExample(b, allocator, mode, target);
}
