const log = @import("std").log;

// util =========================================================================================

pub fn err(e: ?anyerror, msg: []const u8) void {
    if (e == null)
        log.err("{s} failed", .{msg})
    else
        log.err("{s}: {s}", .{ msg, @errorName(e orelse unreachable) });
}
