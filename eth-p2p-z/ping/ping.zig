pub const std_options = @import("zig-libp2p").std_options;

const std = @import("std");
const libp2p = @import("zig-libp2p");
const io_loop = libp2p.thread_event_loop;
const quic = libp2p.transport.quic;
const identity = libp2p.identity;
const swarm = libp2p.swarm;
const protocols = libp2p.protocols;
const ping = libp2p.protocols.ping;
const keys = @import("peer_id").keys;
const multiaddr = @import("multiformats").multiaddr;
const Multiaddr = multiaddr.Multiaddr;

const Args = struct {
    port: u16,
    destination: ?[]const u8,

    fn parse(allocator: std.mem.Allocator) !Args {
        var args = try std.process.argsWithAllocator(allocator);
        defer args.deinit();

        _ = args.next(); // skip program name

        var port: u16 = 0;
        var destination: ?[]const u8 = null;

        while (args.next()) |arg| {
            if (std.mem.eql(u8, arg, "-p") or std.mem.eql(u8, arg, "--port")) {
                if (args.next()) |port_str| {
                    port = try std.fmt.parseInt(u16, port_str, 10);
                } else {
                    return error.MissingPortValue;
                }
            } else if (std.mem.eql(u8, arg, "-d") or std.mem.eql(u8, arg, "--destination")) {
                if (args.next()) |dest| {
                    destination = try allocator.dupe(u8, dest);
                } else {
                    return error.MissingDestinationValue;
                }
            } else if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
                printHelp();
                std.process.exit(0);
            }
        }

        return Args{
            .port = port,
            .destination = destination,
        };
    }

    fn deinit(self: *Args, allocator: std.mem.Allocator) void {
        if (self.destination) |dest| {
            allocator.free(dest);
        }
    }

    fn printHelp() void {
        const help =
            \\Usage: ping [OPTIONS]
            \\
            \\This program demonstrates a simple p2p ping application using libp2p.
            \\
            \\To use it, first run 'ping -p <PORT>', where <PORT> is the port number.
            \\Then, run another instance with 'ping -p <ANOTHER_PORT> -d <DESTINATION>',
            \\where <DESTINATION> is the multiaddress of the previous listener host.
            \\
            \\Options:
            \\  -p, --port <PORT>              Source port number (default: 0 for auto)
            \\  -d, --destination <MULTIADDR>  Destination multiaddr string
            \\  -h, --help                     Show this help message
            \\
            \\Example:
            \\  Listener: ping -p 4001
            \\  Dialer:   ping -p 4002 -d /ip4/127.0.0.1/udp/4001/quic-v1/p2p/16Uiu2HAm...
            \\
        ;
        std.debug.print("{s}", .{help});
    }
};

const PingResultCtx = struct {
    event: std.Thread.ResetEvent = .{},
    result_ns: ?u64 = null,
    err: ?anyerror = null,
    sender: ?*ping.PingStream = null,

    fn callback(ctx: ?*anyopaque, sender: ?*ping.PingStream, res: anyerror!u64) void {
        const self: *PingResultCtx = @ptrCast(@alignCast(ctx.?));
        self.result_ns = res catch |err| {
            self.err = err;
            self.sender = sender;
            self.event.set();
            return;
        };
        self.sender = sender;
        self.event.set();
    }
};

fn findFreePort() !u16 {
    // Bind to port 0 to let the OS assign a free port
    const address = try std.net.Address.parseIp("127.0.0.1", 0);
    const sock = try std.posix.socket(address.any.family, std.posix.SOCK.DGRAM, 0);
    defer std.posix.close(sock);

    try std.posix.bind(sock, &address.any, address.getOsSockLen());

    var bound_addr: std.posix.sockaddr = undefined;
    var addr_len: std.posix.socklen_t = @sizeOf(std.posix.sockaddr);
    try std.posix.getsockname(sock, &bound_addr, &addr_len);

    const net_addr = std.net.Address.initPosix(@alignCast(&bound_addr));
    return net_addr.getPort();
}

fn runListener(
    allocator: std.mem.Allocator,
    switcher: *swarm.Switch,
    transport: *quic.QuicTransport,
    port: u16,
) !void {
    const actual_port = if (port == 0) try findFreePort() else port;

    const listen_addr_str = try std.fmt.allocPrint(
        allocator,
        "/ip4/0.0.0.0/udp/{d}/quic-v1",
        .{actual_port},
    );
    defer allocator.free(listen_addr_str);

    var listen_addr = try Multiaddr.fromString(allocator, listen_addr_str);
    defer listen_addr.deinit();

    try switcher.listen(listen_addr, null, struct {
        fn onStream(_: ?*anyopaque, res: anyerror!?*anyopaque) void {
            _ = res catch |err| {
                std.log.warn("incoming stream error: {any}", .{err});
                return;
            };
        }
    }.onStream);

    const peer_buf = try allocator.alloc(u8, transport.local_peer_id.toBase58Len());
    defer allocator.free(peer_buf);
    const peer_slice = try transport.local_peer_id.toBase58(peer_buf);

    std.debug.print("Listener ready\nConnection strings: -\n", .{});

    // Get and display all listen addresses
    var listen_addrs = try switcher.listenMultiaddrs(allocator);
    defer swarm.Switch.freeListenMultiaddrs(allocator, &listen_addrs);

    for (listen_addrs.items) |addr| {
        const full_addr = try std.fmt.allocPrint(allocator, "{s}/p2p/{s}", .{ addr, peer_slice });
        defer allocator.free(full_addr);
        std.debug.print("{s}\n", .{full_addr});
    }

    // Keep the listener running
    while (true) {
        std.time.sleep(std.time.ns_per_s);
    }
}

fn runDialer(
    allocator: std.mem.Allocator,
    switcher: *swarm.Switch,
    destination: []const u8,
) !void {
    std.debug.print("Dialing {s}\n", .{destination});

    var remote_addr = try Multiaddr.fromString(allocator, destination);
    defer remote_addr.deinit();

    const ping_timeout_ns: u64 = 5 * std.time.ns_per_s;
    const ping_interval_ns = 1 * std.time.ns_per_s;
    var count: usize = 0;

    var ping_service = ping.PingService.init(allocator, switcher);

    while (true) {
        var ping_ctx = PingResultCtx{};

        ping_service.ping(remote_addr, .{ .timeout_ns = ping_timeout_ns }, &ping_ctx, PingResultCtx.callback) catch |err| {
            std.debug.print("Ping #{d} failed to initiate: {any}\n", .{ count, err });
            std.time.sleep(ping_interval_ns);
            count += 1;
            continue;
        };

        ping_ctx.event.wait();

        if (ping_ctx.err) |err| {
            std.debug.print("Ping #{d} failed: {any}\n", .{ count, err });
            std.time.sleep(ping_interval_ns);
            count += 1;
            continue;
        }

        const rtt_ns = ping_ctx.result_ns orelse {
            std.debug.print("Ping #{d} failed: no result\n", .{count});
            std.time.sleep(ping_interval_ns);
            count += 1;
            continue;
        };

        const rtt_ms = @as(f64, @floatFromInt(rtt_ns)) / @as(f64, std.time.ns_per_ms);
        if (count == 0) {
            std.debug.print("Ping successful! RTT: {d:.2}ms\n", .{rtt_ms});
        } else {
            std.debug.print("Ping #{d} successful! RTT: {d:.2}ms\n", .{ count, rtt_ms });
        }

        count += 1;
        std.time.sleep(ping_interval_ns);
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const check = gpa.deinit();
        if (check == .leak) std.log.warn("memory leaked from GPA", .{});
    }
    const allocator = gpa.allocator();

    var args = try Args.parse(allocator);
    defer args.deinit(allocator);

    var loop: io_loop.ThreadEventLoop = undefined;
    try loop.init(allocator);
    defer loop.deinit();

    var host_key = try identity.KeyPair.generate(keys.KeyType.ED25519);
    defer host_key.deinit();

    var transport: quic.QuicTransport = undefined;
    try transport.init(&loop, &host_key, keys.KeyType.ECDSA, allocator);

    var switcher: swarm.Switch = undefined;
    switcher.init(allocator, &transport);
    defer {
        switcher.stop();
        loop.close();
        switcher.deinit();
    }

    var ping_handler = ping.PingProtocolHandler.init(allocator, &switcher);
    defer ping_handler.deinit();
    try switcher.addProtocolHandler(ping.protocol_id, ping_handler.any());

    if (args.destination) |dest| {
        try runDialer(allocator, &switcher, dest);
    } else {
        try runListener(allocator, &switcher, &transport, args.port);
    }
}
