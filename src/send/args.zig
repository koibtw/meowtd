const std = @import("std");
const process = std.process;
const fmt = std.fmt;
const mem = std.mem;

const Args = process.Args;
const ArrayList = std.ArrayList;
const Allocator = mem.Allocator;

const log = @import("log.zig");

// name =========================================================================================

var first: ?[:0]const u8 = null;
fn name() [:0]const u8 {
    return first orelse "meowtd";
}

// parsed =======================================================================================

pub const Parsed = struct {
    message: [:0]const u8,
    address: ?[:0]const u8 = null,
    port: ?u16 = null,
    username: ?[:0]const u8 = null,
    key: ?[:0]const u8 = null,
    passphrase: ?[:0]const u8 = null,
};

// parse ========================================================================================

pub const ParseError = Allocator.Error || OptionError ||
    error{ MissingValue, InvalidArgument, InvalidMessage, NoMessage };

pub fn parse(alloc: Allocator, iter: *Args.Iterator) ParseError!Parsed {
    first = iter.next() orelse return error.NoMessage;

    var result: Parsed = .{ .message = undefined };
    var message: ?[:0]const u8 = null;
    var warned = false;

    while (iter.next()) |arg| {
        if (mem.eql(u8, arg, "--")) {
            var parts = ArrayList([]const u8).empty;
            defer parts.deinit(alloc);

            while (iter.next()) |part| try parts.append(alloc, part);
            if (parts.items.len > 0)
                setMsg(&message, &warned, try mem.joinZ(alloc, " ", parts.items));

            break;
        }

        if (arg.len >= 2 and arg[0] == '-') {
            for (OPTIONS) |opt| {
                if (opt.matches(arg)) {
                    try opt.function(
                        &result,
                        if (opt.needs_arg)
                            iter.next() orelse {
                                log.errRaw("missing value for argument: {s}", .{arg});
                                return error.MissingValue;
                            }
                        else
                            null,
                    );

                    break;
                }
            } else {
                log.errRaw("unknown argument: {s}", .{arg});
                return error.InvalidArgument;
            }

            continue;
        }

        setMsg(&message, &warned, arg);
    }

    result.message = message orelse return error.NoMessage;
    return result;
}

fn setMsg(message: *?[:0]const u8, warned: *bool, content: [:0]const u8) void {
    if (!warned.* and message.* != null) {
        log.warnRaw("got multiple messages", .{});
        log.warnRaw("only the last message will be sent", .{});
        log.warnRaw("for raw input, use: {s} -- <message>", .{name()});
        warned.* = true;
    }
    message.* = content;
}

// option =======================================================================================

const Option = struct {
    arg: [:0]const u8,
    arg_short: ?u8 = null,
    function: *const fn (*Parsed, ?[:0]const u8) ParseError!void,
    needs_arg: bool = false,
    description: []const u8,

    pub fn short(self: Option) u8 {
        return self.arg_short orelse self.arg[0];
    }

    pub fn matches(self: Option, arg: [:0]const u8) bool {
        return (arg[1] == '-' and mem.eql(u8, arg[2..], self.arg)) or
            (arg.len == 2 and arg[1] == self.short());
    }
};

// options ======================================================================================

const OPTIONS = [_]Option{
    .{
        .arg = "verbose",
        .function = &verbose,
        .description = "enable debug logging",
    },
    .{
        .arg = "help",
        .function = &help,
        .description = "show cli help",
    },
    .{
        .arg = "port",
        .function = &setPort,
        .needs_arg = true,
        .description = "set target port",
    },
    .{
        .arg = "address",
        .function = &setAddress,
        .needs_arg = true,
        .description = "set target address",
    },
    .{
        .arg = "username",
        .function = &setUsername,
        .needs_arg = true,
        .description = "set target username",
    },
    .{
        .arg = "key",
        .function = &setKey,
        .needs_arg = true,
        .description = "set private key path",
    },
    .{
        .arg = "passphrase",
        .arg_short = 's',
        .function = &setPassphrase,
        .needs_arg = true,
        .description = "set private key passphrase",
    },
};

// option functions =============================================================================

pub const OptionError = error{InvalidPort};

fn verbose(_: *Parsed, _: ?[:0]const u8) OptionError!void {
    log.setVerbose();
}

fn help(_: *Parsed, _: ?[:0]const u8) OptionError!void {
    log.out("send cute MOTDs to your (girl|enby|boy)friends' computers :3\n", .{});

    log.out("usage:", .{});
    log.out("  {s} [options]    <message>", .{name()});
    log.out("  {s} [options] -- <message>\n", .{name()});

    log.out("options:", .{});
    for (OPTIONS) |opt|
        log.out("  -{c} --{s:<10} {s}", .{ opt.short(), opt.arg, opt.description });

    process.exit(0);
}

fn setPort(result: *Parsed, value: ?[:0]const u8) OptionError!void {
    result.port = fmt.parseInt(u16, value.?, 0) catch return error.InvalidPort;
}

fn setAddress(result: *Parsed, value: ?[:0]const u8) OptionError!void {
    result.address = value;
}

fn setUsername(result: *Parsed, value: ?[:0]const u8) OptionError!void {
    result.username = value;
}

fn setKey(result: *Parsed, value: ?[:0]const u8) OptionError!void {
    result.key = value;
}

fn setPassphrase(result: *Parsed, value: ?[:0]const u8) OptionError!void {
    result.passphrase = value;
}
