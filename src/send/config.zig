const std = @import("std");
const json = std.json;
const mem = std.mem;

const Io = std.Io;
const Dir = Io.Dir;
const File = Io.File;
const Allocator = mem.Allocator;
const Environ = std.process.Environ;

const env = @import("shared").env;
const log = @import("log.zig");

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

// raw ==========================================================================================

const Raw = struct {
    address: ?[]const u8 = null,
    port: ?u16 = null,
    auth: RawAuth = .{},

    const RawAuth = struct {
        username: ?[:0]const u8 = null,
        key: RawKey = .{},

        const RawKey = struct {
            private: ?[:0]const u8 = null,
            public: ?[:0]const u8 = null,
        };
    };
};

// read =========================================================================================

pub const ReadError = Auth.Key.Error || File.OpenError || File.ReadPositionalError ||
    Allocator.Error || json.ParseError(json.Scanner) ||
    error{ NoHome, MissingAddress, MissingKey };
pub fn read(io: Io, alloc: Allocator, map: *Environ.Map, buf: []u8, parsed: anytype) ReadError!Self {
    const home = env.get(map, .HOME) orelse return error.NoHome;
    const config_home = env.get(map, .XDG_CONFIG_HOME) orelse
        try mem.concat(alloc, u8, &.{ home, "/.config" });
    const path = try mem.concat(alloc, u8, &.{
        config_home,
        "/meowtd/config.json",
    });

    log.debug("reading config from {s}", .{path});

    const raw: Raw = blk: {
        const file = Dir.openFileAbsolute(io, path, .{ .allow_directory = false }) catch |e| switch (e) {
            error.FileNotFound => break :blk .{},
            else => return e,
        };

        const bytes = try file.readPositionalAll(io, buf, 0);

        break :blk (try json.parseFromSlice(
            Raw,
            alloc,
            buf[0..bytes],
            .{ .allocate = .alloc_if_needed },
        )).value;
    };

    const address = parsed.address orelse raw.address orelse return error.MissingAddress;
    const private = parsed.key orelse raw.auth.key.private orelse return error.MissingKey;

    var key: Auth.Key = .{
        .private = private,
        .public = raw.auth.key.public,
    };

    try key.expandPrivatePath(alloc, home);
    try key.inferPublic(alloc);

    return .{
        .address = address,
        .port = parsed.port orelse raw.port orelse 22,
        .auth = .{
            .username = parsed.username orelse raw.auth.username orelse "meowtd",
            .key = key,
        },
    };
}
