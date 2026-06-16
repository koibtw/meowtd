// struct =======================================================================================

address: []const u8,
port: u16,

auth: Auth,

// auth =========================================================================================

pub const Auth = struct {
    username: []const u8,
    key: Key,

    pub const Key = struct {
        public: []const u8,
        private: []const u8,
        passphrase: ?[]const u8,
    };
};
