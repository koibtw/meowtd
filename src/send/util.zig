const std = @import("std");
const output = @import("output.zig");

pub fn die(e: ?anyerror, msg: []const u8) noreturn {
    output.err(e, msg);
    std.process.exit(1);
}
