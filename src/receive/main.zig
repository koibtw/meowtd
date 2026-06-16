const std = @import("std");
const process = std.process;

const Io = std.Io;
const Dir = Io.Dir;
const File = Io.File;

const env = @import("env.zig");
const console = @import("util").console;

const Config = @import("config.zig");

// main =========================================================================================

pub fn main(init: process.Init) void {
    const env_map = init.environ_map;
    const io = init.io;

    const config = Config.from_environ_map(env_map) catch |e| die(e, "loding config");
    const message = env.get(env_map, env.K_CMD) orelse die(error.NoMessage, "reading command");

    check_message(config, message) catch |e| die(e, "invalid message");
    write_message(io, config.path, message) catch |e| die(e, "writing motd file");
}

// logic ========================================================================================

const MessageError = error{TooLong};
fn check_message(config: Config, message: []const u8) MessageError!void {
    if (config.max_length != 0 and message.len > config.max_length) return error.TooLong;
}

const WriteError = File.OpenError || File.WriteFilePositionalError;
fn write_message(io: Io, path: []const u8, message: []const u8) WriteError!void {
    const file = try Dir.createFileAbsolute(io, path, .{});
    defer file.close(io);

    try file.writePositionalAll(io, message, 0);
    if (message[message.len - 1] != '\n') try file.writePositionalAll(io, "\n", message.len);
}

// util =========================================================================================

fn die(e: anyerror, comptime msg: []const u8) noreturn {
    console.err(e, msg);
    process.exit(1);
}
