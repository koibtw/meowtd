const std = @import("std");
const fmt = std.fmt;

const env = @import("env.zig");

const Environ = std.process.Environ;

pub const Error = error{NoUser} || fmt.ParseIntError;

// struct =======================================================================================

const Self = @This();

user: []const u8,
path: []const u8 = "/etc/motd",
max_length: usize = 1024,

// init =========================================================================================

pub fn from_environ_map(map: *Environ.Map) Error!Self {
    var self: Self = .{ .user = env.get(map, "USER") orelse return error.NoUser };

    if (env.get(map, env.K_PATH)) |v| self.path = v;
    if (env.get(map, env.K_LEN)) |v| self.max_length = try fmt.parseInt(usize, v, 10);

    return self;
}
