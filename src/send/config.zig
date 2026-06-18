const std = @import("std");
const json = std.json;
const mem = std.mem;

const Io = std.Io;
const Dir = Io.Dir;
const File = Io.File;
const Allocator = mem.Allocator;
const Environ = std.process.Environ;

const env = @import("shared").env;

// struct =======================================================================================

const Self = @This();

address: []const u8,
port: u16 = 22,

auth: Auth,

// auth =========================================================================================

pub const Auth = struct {
    username: [:0]const u8 = "meowtd",
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
pub fn parse(alloc: Allocator, slice: []const u8) ParseError!Self {
    var parsed = try json.parseFromSlice(Self, alloc, slice, .{ .allocate = .alloc_if_needed });
    try parsed.value.auth.key.inferPublic(alloc);

    return parsed.value;
}

// read =========================================================================================

pub const ReadError = ParseError || FilePathError || File.OpenError || File.ReadPositionalError;
pub fn read(io: Io, alloc: Allocator, env_map: *Environ.Map, buf: []u8) ReadError!Self {
    const file = try Dir.openFileAbsolute(
        io,
        try filePath(alloc, env_map),
        .{ .allow_directory = false },
    );

    const bytes = try file.readPositionalAll(io, buf, 0);

    return try parse(alloc, buf[0..bytes]);
}

pub const FilePathError = Allocator.Error || error{NoHome};
fn filePath(alloc: Allocator, map: *Environ.Map) FilePathError![]const u8 {
    const config_home = env.get(map, .XDG_CONFIG_HOME) orelse b: {
        const home = env.get(map, .HOME) orelse return error.NoHome;
        break :b try mem.concat(alloc, u8, &.{ home, "/.config" });
    };

    return try mem.concat(alloc, u8, &.{ config_home, "/meowtd/config.json" });
}
