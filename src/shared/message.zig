const std = @import("std");
const fmt = std.fmt;

const Writer = std.Io.Writer;

// type =========================================================================================

pub const T = u1;
pub const Type = enum(T) {
    success,
    failure,
};

// write ========================================================================================

pub fn writeType(w: *Writer, comptime msg_type: Type) Writer.Error!void {
    try switch (msg_type) {
        .success => w.writeByte('0'),
        .failure => w.writeByte('1'),
    };
}

// struct =======================================================================================

const Self = @This();

msg_type: Type,
content: []const u8,

// parse ========================================================================================

pub const ParseError = fmt.ParseIntError || error{TooShort};
pub fn parse(buf: []const u8) ParseError!Self {
    if (buf.len == 0) return error.TooShort;
    const int = try fmt.parseInt(T, buf[0..1], 2);
    const msg_type: Type = @enumFromInt(int);

    return .{
        .msg_type = msg_type,
        .content = switch (msg_type) {
            .success => "success",
            .failure => buf[1..buf.len],
        },
    };
}
