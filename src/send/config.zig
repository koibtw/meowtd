const std = @import("std");
const json = std.json;
const meta = std.meta;
const mem = std.mem;

const Io = std.Io;
const Dir = Io.Dir;
const File = Io.File;
const Allocator = mem.Allocator;
const Environ = std.process.Environ;

const env = @import("shared").env;
const log = @import("log.zig");

const Parsed = @import("args.zig").Parsed;

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

pub const ReadRawError =  File.OpenError || File.ReadPositionalError || json.ParseError(json.Scanner);
fn readRaw(io: Io, alloc: Allocator, buf: []u8, path: []const u8) ReadRawError!Raw {
    log.debug("reading raw config from {s}", .{path});

    const file = Dir.openFileAbsolute(io, path, .{ .allow_directory = false }) catch |e|
        switch (e) {
            error.FileNotFound => return .{},
            else => return e,
        };

    const bytes = try file.readPositionalAll(io, buf, 0);

    return (try json.parseFromSlice(
        Raw,
        alloc,
        buf[0..bytes],
        .{ .allocate = .alloc_if_needed },
    )).value;
}

// read =========================================================================================

pub const ReadError = ReadRawError || Auth.Key.Error || Allocator.Error ||
    error{ NoHome, MissingAddress, MissingKey };
pub fn read(
    io: Io,
    alloc: Allocator,
    map: *Environ.Map,
    buf: []u8,
    cli: Parsed,
) ReadError!Self {
    const home = env.get(map, .HOME) orelse return error.NoHome;

    const raw: ?Raw = if (cli.address == null or cli.username == null or cli.key == null)
        try readRaw(io, alloc, buf, if (env.get(map, .XDG_CONFIG_HOME)) |xdg|
            try mem.concat(alloc, u8, &.{ xdg, "/meowtd/config.json" })
        else
            try mem.concat(alloc, u8, &.{ home, "/.config/meowtd/config.json" }))
    else
        null;

    const address = (cli.address orelse if (raw) |r| r.address else null) orelse return error.MissingAddress;
    const private = (cli.key orelse if (raw) |r| r.auth.key.private else null) orelse return error.MissingKey;
    const port = (cli.port orelse if (raw) |r| r.port else null) orelse 22;
    const username = (cli.username orelse if (raw) |r| r.auth.username else null) orelse "meowtd";

    var key: Auth.Key = .{
        .private = private,
        .public = if (raw) |r| r.auth.key.public else null,
    };

    try key.expandPrivatePath(alloc, home);
    try key.inferPublic(alloc);

    return .{
        .address = address,
        .port = port,
        .auth = .{
            .username = username,
            .key = key,
        },
    };
}
