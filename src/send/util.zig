const std = @import("std");
const log = @import("log.zig");

pub fn die(e: ?anyerror, msg: []const u8) noreturn {
    log.err(e, msg);
    std.process.exit(1);
}
