const std = @import("std");
const fmt = std.fmt;

const Writer = std.Io.Writer;

const VERSION = @import("version.zig").VERSION;

// type =========================================================================================

pub const T = u1;
pub const Type = enum(T) {
    success,
    failure,
};

// prefix =======================================================================================

pub fn writePrefix(w: *Writer, msg_type: Type) Writer.Error!void {
    try switch (msg_type) {
        .success => w.writeByte('0'),
        .failure => w.writeByte('1'),
    };
    try w.writeAll(VERSION);
}

// struct =======================================================================================

const Self = @This();

version: *const [VERSION.len]u8,
msg_type: Type,
content: []const u8,

// parse ========================================================================================

pub const ParseError = fmt.ParseIntError || error{ TooShort, BadVersion };
pub fn parse(buf: []const u8) ParseError!Self {
    if (buf.len == 0) return error.TooShort;
    if (buf.len < 6) return error.BadVersion;

    const msg_type: Type = @enumFromInt(try fmt.parseInt(T, buf[0..1], 2));
    return .{
        .version = buf[1..1+VERSION.len],
        .msg_type = msg_type,
        .content = switch (msg_type) {
            .success => "success",
            .failure => buf[1 + VERSION.len .. buf.len],
        },
    };
}
