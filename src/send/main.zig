const builtin = @import("builtin");

const std = @import("std");
const process = std.process;
const mem = std.mem;
const log = std.log;
const net = Io.net;

const Io = std.Io;
const Stream = net.Stream;
const HostName = net.HostName;

const c = @import("libssh2");

const Session = c.LIBSSH2_SESSION;
const Channel = c.LIBSSH2_CHANNEL;

const console = @import("util").console;

// constants ====================================================================================

const HOST = "localhost";
const PORT = 22;
const USER = "koi";

const KEY = "/home/koi/.ssh/id_ed25519";
const KEY_PUB = "/home/koi/.ssh/id_ed25519.pub";
const KEY_PASS = null;

// main =========================================================================================

pub fn main(init: process.Init) void {
    const io = init.io;

    const session = initialize() catch |e| die(e, "session initialization");

    const stream = connect(io) catch |e| {
        disconnect(session);
        die(e, "connecting stream");
    };

    const channel = open(session, stream) catch |e| {
        disconnect(session);
        stream.close(io);
        die(e, "opening channel");
    };

    execute(channel) catch |e| {
        close(channel);
        disconnect(session);
        stream.close(io);
        die(e, "sending data");
    };

    close(channel);
    disconnect(session);
    stream.close(io);
    c.libssh2_exit();
}

// init =========================================================================================

const InitError = error{ SSHInitFailed, SessionInitFailed };
fn initialize() InitError!*Session {
    cr(c.libssh2_init(0)) catch return error.SSHInitFailed;

    const session = c.libssh2_session_init_wrapped() orelse return error.SessionInitFailed;
    if (builtin.mode == .Debug) _ = c.libssh2_trace(session, ~@as(c_int, 0));

    return session;
}

// connect ======================================================================================

const ConnectError = HostName.ValidateError || HostName.ConnectError;
fn connect(io: Io) ConnectError!Stream {
    const hostname = try HostName.init(HOST);
    return try hostname.connect(io, PORT, .{
        .mode = .stream,
        .protocol = .tcp,
        .timeout = .none, // TODO: set timeout
    });
}

// open =========================================================================================

const OpenError = error{ HandshakeFailed, AuthUnsupported, AuthFailed, ChannelOpenFailed };
fn open(session: *Session, stream: Stream) OpenError!*Channel {
    cr(c.libssh2_session_handshake(session, stream.socket.handle)) catch
        return error.HandshakeFailed;

    // TODO: fingerprint verification with known_hosts maybe
    //       idk tho we dont really need it tbh cause like what someones gonna MITM a MOTD lol

    const fingerprint = c.libssh2_hostkey_hash(session, c.LIBSSH2_HOSTKEY_HASH_SHA256);

    if (fingerprint == null)
        log.warn("failed to obtain host fingerprint", .{})
    else if (builtin.mode == .Debug) {
        var buf: [32 * 2]u8 = undefined;
        var writer = Io.Writer.fixed(&buf);
        writer.printHex(fingerprint[0..32], .lower) catch {};
        log.debug("host fingerprint: {s}", .{writer.buffer});
    }

    const authListC = c.libssh2_userauth_list(session, USER, USER.len) orelse
        return error.AuthUnsupported;

    const authList = mem.span(authListC);
    if (!mem.containsAtLeast(u8, authList, 1, "publickey")) return error.AuthUnsupported;

    cr(c.libssh2_userauth_publickey_fromfile(session, USER, KEY_PUB, KEY, KEY_PASS)) catch
        return error.AuthFailed;

    return c.libssh2_channel_open_session_wrapped(session) orelse error.ChannelOpenFailed;
}

// execute ======================================================================================

const ExecError = error{ CommandRequestFailed, ReadStderrFailed };
fn execute(channel: *Channel) ExecError!void {
    cr(c.libssh2_channel_exec_wrapped(channel, "meow")) catch return error.CommandRequestFailed;

    var stderr_buf: [1024]u8 = undefined;
    while (c.libssh2_channel_eof(channel) == 0) {
        const stderr_read = c.libssh2_channel_read_stderr(channel, &stderr_buf, stderr_buf.len);
        if (stderr_read < 0) return error.ReadStderrFailed;

        // TODO: make this smart and handle communication internally
        std.debug.print("{s}", .{stderr_buf[0..@intCast(stderr_read)]});
    }

    // FIXME: this might not be available yet i think but whatever
    const exit_status = c.libssh2_channel_get_exit_status(channel);
    log.debug("exit status: {d}", .{exit_status});
}

// cleanup ======================================================================================

// FIXME: use disconnect ONLY after the hanshake, NEVER before
fn disconnect(session: *Session) void {
    _ = c.libssh2_session_disconnect(session, "byebye :3");
    _ = c.libssh2_session_free(session);
}

fn close(channel: *Channel) void {
    _ = c.libssh2_channel_close(channel);
    _ = c.libssh2_channel_free(channel);
}

// util =========================================================================================

const CError = error{FunctionFailed};
fn cr(ret: c_int) CError!void {
    if (ret < 0) return error.FunctionFailed;
}

// TODO: real errors with libssh2_session_last_error and so on
fn die(e: ?anyerror, comptime msg: []const u8) noreturn {
    console.err(e, msg);
    c.libssh2_exit();
    process.exit(1);
}
