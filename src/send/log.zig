const builtin = @import("builtin");

const std = @import("std");
const log = std.log;

const Io = std.Io;
const File = Io.File;
const Writer = Io.Writer;

// stdout =======================================================================================

var out_buf: [1024]u8 = undefined;
var out_writer: File.Writer = undefined;

pub fn init(io: Io) void {
    out_writer = File.stdout().writer(io, &out_buf);
}

pub fn out(comptime format: []const u8, args: anytype) void {
    const w = &out_writer.interface;

    w.print(format ++ "\n", args) catch |e| err(e, "printing to stdout");
    w.flush() catch |e| err(e, "flushing stdout");
}

// verbose ======================================================================================

var verbose = builtin.mode == .Debug;

pub fn setVerbose() void {
    verbose = true;
}

// raw ==========================================================================================

pub fn errRaw(comptime format: []const u8, args: anytype) void {
    log.defaultLog(.err, .default, format, args);
}

pub fn warnRaw(comptime format: []const u8, args: anytype) void {
    log.defaultLog(.warn, .default, format, args);
}

pub fn info(comptime format: []const u8, args: anytype) void {
    log.defaultLog(.info, .default, format, args);
}

pub fn debug(comptime format: []const u8, args: anytype) void {
    if (verbose) log.defaultLog(.debug, .default, format, args);
}

// errors =======================================================================================

pub fn err(e: ?anyerror, msg: []const u8) void {
    if (e) |v|
        errRaw("{s}: {s}", .{ msg, @errorName(v) })
    else
        errRaw("{s} failed", .{msg});
}

pub fn warn(e: ?anyerror, msg: []const u8) void {
    if (e) |v|
        warnRaw("{s}: {s}", .{ msg, @errorName(v) })
    else
        warnRaw("{s}", .{msg});
}
