const std = @import("std");
const process = std.process;
const heap = std.heap;
const mem = std.mem;

const log = @import("log.zig");
const util = @import("util.zig");
const args = @import("args.zig");

const Config = @import("config.zig");
const Client = @import("client.zig");

// main =========================================================================================

pub fn main(init: process.Init) void {
    const alloc = init.arena.allocator();
    const env_map = init.environ_map;
    const io = init.io;

    log.init(io);

    var args_iter = init.minimal.args.iterate();
    const args_parsed = args.parse(alloc, &args_iter) catch |e| util.die(e, "parsing arguments");
    args_iter.deinit();

    var config_buf: [1024]u8 = undefined;
    const config = Config.read(io, alloc, env_map, &config_buf, args_parsed) catch |e|
        util.die(e, "reading config");

    var client: Client = .{
        .io = io,
        .message = args_parsed.message,
        .config = config,
    };

    client.streamConnect() catch |e| client.die(e, "connecting stream");
    client.sessionInit() catch |e| client.die(e, "session initialization");
    client.channelOpen(args_parsed.passphrase) catch |e| client.die(e, "opening channel");

    client.send() catch |e| client.die(e, "sending data");
    client.readResponse() catch |e| client.die(e, "reading response");
    const exit_status = client.channelWait() catch |e| client.die(e, "closing channel");

    client.deinit();
    process.exit(exit_status);
}
