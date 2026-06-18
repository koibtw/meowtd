const std = @import("std");
const process = std.process;
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

// parse ========================================================================================

pub const ParseError = Allocator.Error || error{ InvalidArgument, InvalidMessage, NoMessage };
pub fn parse(alloc: Allocator, iter: *Args.Iterator) ParseError![:0]const u8 {
    first = iter.next() orelse return error.NoMessage;

    var message: ?[:0]const u8 = null;
    while (iter.next()) |arg| {
        if (mem.eql(u8, arg, "--")) {
            var parts = ArrayList([]const u8).empty;
            defer parts.deinit(alloc);

            while (iter.next()) |part| try parts.append(alloc, part);
            if (parts.items.len > 0) message = try mem.joinZ(alloc, " ", parts.items);

            break;
        }

        if (arg.len >= 2 and arg[0] == '-') {
            var valid = false;

            for (OPTIONS) |opt| {
                const is_long = arg[1] == '-' and mem.eql(u8, arg[2..], opt.long);
                if (is_long or mem.eql(u8, arg[1..], opt.short)) {
                    opt.function();
                    valid = true;
                }
            }

            if (!valid) {
                log.errRaw("unknown argument: {s}", .{arg});
                return error.InvalidArgument;
            }

            continue;
        }

        if (message == null) {
            message = arg;
        } else {
            log.warnRaw("got multiple messages", .{});
            log.warnRaw("only the last message will be sent", .{});
            log.warnRaw("for raw input, use: {s} -- <message>", .{name()});
        }
    }

    return message orelse return error.NoMessage;
}

// option =======================================================================================

const Option = struct {
    short: [:0]const u8,
    long: [:0]const u8,
    function: *const fn () void,
    description: []const u8,
};

// options ======================================================================================

const OPTIONS = [_]Option{
    .{
        .short = "v",
        .long = "verbose",
        .function = &verbose,
        .description = "enable debug logging",
    },
    .{
        .short = "h",
        .long = "help",
        .function = &help,
        .description = "show cli help",
    },
};

// option functions =============================================================================

fn verbose() void {
    log.setVerbose();
}

fn help() void {
    log.out("send cute MOTDs to your (girl|enby|boy)friends' computers :3\n", .{});

    log.out("usage:", .{});
    log.out("  {s} [options]    <message>", .{name()});
    log.out("  {s} [options] -- <message>\n", .{name()});

    log.out("options:", .{});
    for (OPTIONS) |opt|
        log.out("  -{s} --{s:<10} {s}", .{ opt.short, opt.long, opt.description });

    process.exit(0);
}
