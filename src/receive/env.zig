const Environ = @import("std").process.Environ;

// constants ====================================================================================

pub const K_PATH = "MEOWTD_PATH";
pub const K_LEN = "MEOWTD_MAX_LENGTH";
pub const K_CMD = "SSH_ORIGINAL_COMMAND";

// util =========================================================================================

pub fn get(map: *Environ.Map, comptime key: []const u8) ?[]const u8 {
    if (map.get(key)) |v| if (v.len != 0) return v;
    return null;
}
