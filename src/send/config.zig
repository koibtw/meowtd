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

        pub const InferPublicError = Allocator.Error;
        pub fn inferPublic(self: *Key, alloc: Allocator) InferPublicError!void {
            if (self.public != null) return;
            self.public = try mem.concatWithSentinel(alloc, u8, &.{ self.private, ".pub" }, 0);
        }
    };
};

// parse ========================================================================================

pub const ParseError = json.ParseError(json.Scanner) || Auth.Key.InferPublicError;
pub fn parse(alloc: Allocator, slice: []const u8) ParseError!json.Parsed(Self) {
    var parsed = try json.parseFromSlice(Self, alloc, slice, .{ .allocate = .alloc_if_needed });
    try parsed.value.auth.key.inferPublic(alloc);

    return parsed;
}
