const builtin = @import("builtin");
const log = @import("std").log;

// variables ====================================================================================

var verbose = builtin.mode == .Debug;

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
