const std = @import("std");
const process = std.process;

const Client = @import("client.zig");

// main =========================================================================================

pub fn main(init: process.Init) void {
    var client: Client = .{
        .io = init.io,
        .message = "meowtd test :3",
        .config = .{
            .address = "localhost",
            .port = 22,
            .auth = .{
                .username = "koi",
                .key = .{
                    .public = "/home/koi/.ssh/id_ed25519.pub",
                    .private = "/home/koi/.ssh/id_ed25519",
                    .passphrase = null,
                },
            },
        },
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
