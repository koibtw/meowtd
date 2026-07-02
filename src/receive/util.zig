const std = @import("std");
const process = std.process;

const Writer = std.Io.Writer;

const Message = @import("shared").Message;

pub fn success(w: *Writer) Writer.Error!void {
    try Message.writePrefix(w, .success);
    try w.flush();
}

fn failure(w: *Writer, e: anyerror, msg: []const u8) Writer.Error!void {
    try Message.writePrefix(w, .failure);
    try w.writeAll(msg);
    try w.writeAll(": ");
    try w.writeAll(@errorName(e));
    try w.flush();
}

pub fn die(w: *Writer, e: anyerror, msg: []const u8) noreturn {
    failure(w, e, msg) catch {};
    process.exit(1);
}
