const std = @import("std");
const process = std.process;

const util = @import("util.zig");

const Config = @import("config.zig");
const Client = @import("client.zig");

// main =========================================================================================

pub fn main(init: process.Init) void {
    const alloc = init.arena.allocator();
    const io = init.io;

    const config = Config.parse(alloc,
        \\{
        \\  "address": "localhost",
        \\  "auth": {
        \\    "username": "koi",
        \\    "key": {
        \\      "private": "/home/koi/.ssh/id_ed25519"
        \\    }
        \\  }
        \\}
    ) catch |e| util.die(e, "parsing config");

    var client: Client = .{
        .io = io,
        .message = "meowtd test :3",
        .config = config.value,
    };

    client.sessionInit() catch |e| client.die(e, "session initialization");
    client.streamConnect() catch |e| client.die(e, "connecting stream");
    client.channelOpen() catch |e| client.die(e, "opening channel");

    client.send() catch |e| client.die(e, "sending data");
    client.readResponse() catch |e| client.die(e, "reading response");
    const exit_status = client.channelWait() catch |e| client.die(e, "closing channel");

    client.deinit();
    process.exit(exit_status);
}
