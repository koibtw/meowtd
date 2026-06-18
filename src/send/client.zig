const std = @import("std");
const process = std.process;
const mem = std.mem;
const log = std.log;
const net = Io.net;

const Io = std.Io;
const Writer = Io.Writer;
const Stream = net.Stream;
const HostName = net.HostName;

const c = @import("libssh2");

const Session = c.LIBSSH2_SESSION;
const Channel = c.LIBSSH2_CHANNEL;

const shared = @import("shared");

const Message = shared.Message;

const builtin = @import("builtin");
const output = @import("output.zig");
const util = @import("util.zig");

const Config = @import("config.zig");

// constants ====================================================================================

pub const NullChannelError = error{NullChannel};

const FP_SIZE = 32;

// struct =======================================================================================

const Self = @This();

io: Io,

config: Config,
message: [*:0]const u8,

stream: ?Stream = null,

session: ?*Session = null,
channel: ?*Channel = null,

// stream =======================================================================================

pub const StreamConnectError = HostName.ValidateError || HostName.ConnectError;
pub fn streamConnect(self: *Self) StreamConnectError!void {
    const address = self.config.address;
    const port = self.config.port;

    log.debug("connecting to {s}:{d}", .{ address, port });

    const hostname = try HostName.init(address);
    self.stream = try hostname.connect(self.io, port, .{
        .mode = .stream,
        .protocol = .tcp,
        .timeout = .none, // TODO: set timeout
    });
}

// session ======================================================================================

pub const SessionInitError = error{ SshInitFailed, SessionInitFailed };
pub fn sessionInit(self: *Self) SessionInitError!void {
    log.debug("initializing SSH session", .{});

    cr(c.libssh2_init(0)) catch return error.SshInitFailed;

    self.session = c.libssh2_session_init_wrapped() orelse return error.SessionInitFailed;
    if (builtin.mode == .Debug) _ = c.libssh2_trace(self.session, ~@as(c_int, 0));
}

// channel ======================================================================================

pub const ChannelOpenError = AuthenticateError ||
    error{ NullStream, NullSession, SessionHandshakeFailed, OpenFailed };
pub fn channelOpen(self: *Self) ChannelOpenError!void {
    const socket = (self.stream orelse return error.NullStream).socket.handle;
    const session = self.session orelse return error.NullSession;

    log.debug("opening SSH channel on socket {}", .{socket});

    cr(c.libssh2_session_handshake(session, socket)) catch return error.SessionHandshakeFailed;

    obtainFingerprint(session);
    try authenticate(session, self.config.auth);

    self.channel = c.libssh2_channel_open_session_wrapped(session) orelse
        return error.OpenFailed;
}

pub const AuthenticateError = error{ NullPubkey, AuthUnsupported, AuthFailed };
fn authenticate(session: *Session, data: Config.Auth) AuthenticateError!void {
    const listC = c.libssh2_userauth_list(
        session,
        data.username.ptr,
        @intCast(data.username.len),
    ) orelse return error.AuthUnsupported;

    const list = mem.span(listC);
    if (!mem.containsAtLeast(u8, list, 1, "publickey")) return error.AuthUnsupported;

    const pubkey = data.key.public orelse return error.NullPubkey;

    log.debug("authenticating as {s} with {s} and {s}", .{
        data.username,
        data.key.private,
        pubkey,
    });

    cr(c.libssh2_userauth_publickey_fromfile(
        session,
        data.username.ptr,
        pubkey.ptr,
        data.key.private.ptr,
        if (data.key.passphrase) |p| p.ptr else null,
    )) catch return error.AuthFailed;
}

// TODO: fingerprint verification with known_hosts maybe
//       idk tho we dont really need it tbh cause like what someones gonna MITM a MOTD lol
fn obtainFingerprint(session: *Session) void {
    const fingerprint = c.libssh2_hostkey_hash(session, c.LIBSSH2_HOSTKEY_HASH_SHA256);
    if (fingerprint == null)
        log.warn("failed to obtain host fingerprint", .{})
    else if (builtin.mode == .Debug) {
        var writer_buf: [6 + FP_SIZE * 2]u8 = undefined;
        var writer = Writer.fixed(&writer_buf);
        encodeFingerprint(&writer, fingerprint[0..FP_SIZE]) catch |e|
            output.warn(e, "failed to encode host fingerprint");
        log.debug("host fingerprint: {s}", .{writer.buffer});
    }
}

fn encodeFingerprint(w: *Writer, fp: *const [FP_SIZE]u8) Writer.Error!void {
    try w.writeAll("SHA256:");
    try w.printBase64(fp);
}

pub const ChannelWaitError = NullChannelError || error{ WaitEofFailed, WaitClosedFailed };
pub fn channelWait(self: *Self) ChannelWaitError!u8 {
    const channel = self.channel orelse return error.NullChannel;

    log.debug("waiting for the channel to close", .{});

    cr(c.libssh2_channel_wait_eof(channel)) catch return error.WaitEofFailed;
    cr(c.libssh2_channel_wait_closed(channel)) catch return error.WaitClosedFailed;

    const exit_status = c.libssh2_channel_get_exit_status(channel);
    log.debug("raw exit status: {d}", .{exit_status});

    return @intCast(exit_status);
}

// execute ======================================================================================

pub const SendError = NullChannelError || error{CommandRequestFailed};
pub fn send(self: *Self) SendError!void {
    const channel = self.channel orelse return error.NullChannel;

    log.debug("sending data: {s}", .{self.message});

    cr(c.libssh2_channel_exec_wrapped(
        channel,
        self.message,
    )) catch return error.CommandRequestFailed;
}

pub const ReadResponseError = NullChannelError || error{IoReadFailed};
pub fn readResponse(self: *Self) ReadResponseError!void {
    const channel = self.channel orelse return error.NullChannel;

    log.debug("reading stdout once", .{});

    var buf: [shared.IO_SIZE]u8 = undefined;
    const read = c.libssh2_channel_read(channel, &buf, buf.len);
    if (read < 0) return error.IoReadFailed;
    parseResponse(buf[0..@intCast(read)]) catch |e| output.err(e, "parsing response");
}

fn parseResponse(buf: []const u8) Message.ParseError!void {
    const response = try Message.parse(buf);
    switch (response.msg_type) {
        .success => log.info("{s}", .{response.content}),
        .failure => log.err("{s}", .{response.content}),
    }
}

// deinit =======================================================================================

pub fn deinit(self: *Self) void {
    if (self.channel) |channel| {
        _ = c.libssh2_channel_close(channel);
        _ = c.libssh2_channel_free(channel);
        self.channel = null;
    }

    if (self.session) |session| {
        _ = c.libssh2_session_disconnect(session, "byebye :3");
        _ = c.libssh2_session_free(session);
        self.session = null;
    }

    if (self.stream) |stream| {
        stream.close(self.io);
        self.stream = null;
    }

    c.libssh2_exit();
}

// util =========================================================================================

const CError = error{FunctionFailed};
fn cr(ret: c_int) CError!void {
    if (ret < 0) return error.FunctionFailed;
}

pub fn die(self: *Self, e: anyerror, msg: []const u8) noreturn {
    if (self.session) |session| {
        var message: ?[*:0]u8 = null;
        const code = c.libssh2_session_last_error(session, @ptrCast(&message), null, 0);
        log.err("libssh2 ({d}): {s}", .{ code, message orelse "No error message" });
    }

    self.deinit();
    util.die(e, msg);
}
