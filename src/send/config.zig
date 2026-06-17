const std = @import("std");
const json = std.json;
const mem = std.mem;

const Allocator = std.mem.Allocator;

// struct =======================================================================================

const Self = @This();

address: []const u8,
port: u16 = 22,

auth: Auth,

// auth =========================================================================================

pub const Auth = struct {
    username: [:0]const u8,
    key: Key,

    pub const Key = struct {
        private: [:0]const u8,
        public: ?[:0]const u8 = null,
        passphrase: ?[:0]const u8 = null,
    };
};

// parse ========================================================================================

pub const ParseError = json.ParseError(json.Scanner) || Allocator.Error;
pub fn parse(alloc: Allocator, slice: []const u8) ParseError!json.Parsed(Self) {
    var parsed = try json.parseFromSlice(Self, alloc, slice, .{ .allocate = .alloc_if_needed });

    const config = &parsed.value;
    if (config.auth.key.public == null) config.auth.key.public =
        try mem.concatWithSentinel(alloc, u8, &.{ config.auth.key.private, ".pub" }, 0);

    return parsed;
}
