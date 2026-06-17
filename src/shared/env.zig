const Environ = @import("std").process.Environ;

// key ==========================================================================================

pub const Key = enum {
    MEOWTD_PATH,
    MEOWTD_MAX_LENGTH,

    SSH_ORIGINAL_COMMAND,

    USER,
    HOME,
    XDG_CONFIG_HOME,
};

// util =========================================================================================

pub fn get(map: *Environ.Map, key: Key) ?[]const u8 {
    if (map.get(@tagName(key))) |v| if (v.len != 0) return v;
    return null;
}
