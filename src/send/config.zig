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

        pub const Error = Allocator.Error;

        pub fn expandPrivatePath(self: *Key, alloc: Allocator, home: []const u8) Error!void {
            if (!mem.startsWith(u8, self.private, "~/")) return;
            self.private = try mem.concatWithSentinel(alloc, u8, &.{
                home,
                self.private[1..],
            }, 0);
        }

        pub fn inferPublic(self: *Key, alloc: Allocator) Error!void {
            if (self.public != null) return;
            self.public = try mem.concatWithSentinel(alloc, u8, &.{
                self.private,
                ".pub",
            }, 0);
        }
    };
};

// read =========================================================================================

pub const ReadError = Auth.Key.Error || File.OpenError || File.ReadPositionalError ||
    Allocator.Error || json.ParseError(json.Scanner) || error{NoHome};
pub fn read(io: Io, alloc: Allocator, map: *Environ.Map, buf: []u8) ReadError!Self {
    const home = env.get(map, .HOME) orelse return error.NoHome;
    const config_home = env.get(map, .XDG_CONFIG_HOME) orelse
        try mem.concat(alloc, u8, &.{ home, "/.config" });

    const file = try Dir.openFileAbsolute(
        io,
        try mem.concat(alloc, u8, &.{
            config_home,
            "/meowtd/config.json",
        }),
        .{ .allow_directory = false },
    );

    const bytes = try file.readPositionalAll(io, buf, 0);

    var parsed = (try json.parseFromSlice(
        Self,
        alloc,
        buf[0..bytes],
        .{ .allocate = .alloc_if_needed },
    )).value;

    try parsed.auth.key.expandPrivatePath(alloc, home);
    try parsed.auth.key.inferPublic(alloc);

    return parsed;
}
