const log = @import("std").log;

// util =========================================================================================

pub fn err(e: anyerror, comptime msg: []const u8) void {
    log.err("{s}: {s}", .{ msg, @errorName(e) });
}
