const std = @import("std");
const process = std.process;

const Io = std.Io;
const Dir = Io.Dir;
const File = Io.File;
const Writer = Io.Writer;

const env = @import("env.zig");

const Message = @import("shared").Message;
const Config = @import("config.zig");

// main =========================================================================================

pub fn main(init: process.Init) void {
    const env_map = init.environ_map;
    const io = init.io;

    var writer_buf: [128]u8 = undefined;
    var writer = File.stdout().writer(io, &writer_buf);
    const w = &writer.interface;

    const config = Config.from_environ_map(env_map) catch |e| die(w, e, "loding config");
    const command = env.get(env_map, env.CMD) orelse die(w, error.NoMessage, "reading command");

    check_message(config, command) catch |e| die(w, e, "invalid message");
    write_message(io, config.path, command) catch |e| die(w, e, "writing motd file");

    success(w) catch {};
}

// logic ========================================================================================

const MessageError = error{TooLong};
fn check_message(config: Config, command: []const u8) MessageError!void {
    if (config.max_length != 0 and command.len > config.max_length) return error.TooLong;
}

const WriteError = File.OpenError || File.WriteFilePositionalError;
fn write_message(io: Io, path: []const u8, command: []const u8) WriteError!void {
    const file = try Dir.createFileAbsolute(io, path, .{});
    defer file.close(io);

    try file.writePositionalAll(io, command, 0);
    if (command[command.len - 1] != '\n') try file.writePositionalAll(io, "\n", command.len);
}

// util =========================================================================================

fn success(w: *Writer) Writer.Error!void {
    try Message.writeType(w, .success);
    try w.flush();
}

fn failure(w: *Writer, e: anyerror, comptime msg: []const u8) Writer.Error!void {
    try Message.writeType(w, .failure);
    try w.writeAll(msg);
    try w.writeAll(": ");
    try w.writeAll(@errorName(e));
    try w.flush();
}

fn die(w: *Writer, e: anyerror, comptime msg: []const u8) noreturn {
    failure(w, e, msg) catch {};
    process.exit(1);
}
