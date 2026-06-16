const Environ = @import("std").process.Environ;

// constants ====================================================================================

pub const PATH = "MEOWTD_PATH";
pub const LEN = "MEOWTD_MAX_LENGTH";
pub const CMD = "SSH_ORIGINAL_COMMAND";

// util =========================================================================================

pub fn get(map: *Environ.Map, key: []const u8) ?[]const u8 {
    if (map.get(key)) |v| if (v.len != 0) return v;
    return null;
}
