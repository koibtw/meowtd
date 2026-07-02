const std = @import("std");
const fmt = std.fmt;

const Build = std.Build;
const Step = Build.Step;
const Compile = Step.Compile;
const TranslateC = Step.TranslateC;
const Module = Build.Module;
const ResolvedTarget = Build.ResolvedTarget;
const OptimizeMode = std.builtin.OptimizeMode;
const Error = std.mem.Allocator.Error;

const zon = @import("build.zig.zon");

const Self = @This();

b: *Build,
target: ResolvedTarget,
optimize: OptimizeMode,

pub fn build(b: *Build) Error!void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    var self: Self = .{ .b = b, .target = target, .optimize = optimize };

    const options = b.addOptions();
    options.addOption([]const u8, "version", zon.version);

    const shared = self.mod("src/shared/root.zig");
    const libssh2 = self.c("src/send/libssh2.h");
    libssh2.linkSystemLibrary("libssh2", .{});

    const send = self.mod("src/send/main.zig");
    send.addOptions("options", options);
    send.addImport("shared", shared);
    send.addImport("libssh2", libssh2.createModule());

    const receive = self.mod("src/receive/main.zig");
    receive.addImport("shared", shared);

    try self.exe("meowtd", send);
    try self.exe("meowtd-receive", receive);
}

fn mod(self: *Self, comptime path: []const u8) *Module {
    const b = self.b;

    return b.createModule(.{
        .root_source_file = b.path(path),
        .target = self.target,
        .optimize = self.optimize,
    });
}

fn c(self: *Self, comptime path: []const u8) *TranslateC {
    const b = self.b;

    return b.addTranslateC(.{
        .root_source_file = b.path(path),
        .target = self.target,
        .optimize = self.optimize,
    });
}

fn exe(self: *Self, comptime name: []const u8, root_module: *Module) Error!void {
    const b = self.b;

    const e = b.addExecutable(.{ .name = name, .root_module = root_module });
    b.installArtifact(e);

    try self.install_step(name, e);
    try self.run_step(name, e);
}

fn install_step(self: *Self, comptime name: []const u8, artifact: *Compile) Error!void {
    const b = self.b;
    const allocator = b.allocator;

    const step_description =
        try fmt.allocPrint(allocator, "Copy {s} build artifacts to prefix path", .{name});

    const step = b.step(name, step_description);
    step.dependOn(&artifact.step);

    const cmd = b.addInstallArtifact(artifact, .{});
    step.dependOn(&cmd.step);
}

fn run_step(self: *Self, comptime name: []const u8, artifact: *Compile) Error!void {
    const b = self.b;
    const allocator = b.allocator;

    const step_name = try fmt.allocPrint(allocator, "run-{s}", .{name});
    const step_description =
        try fmt.allocPrint(allocator, "Run {s} build artifacts", .{name});

    const step = b.step(step_name, step_description);
    step.dependOn(&artifact.step);

    const cmd = b.addRunArtifact(artifact);
    if (b.args) |a| cmd.addArgs(a);
    step.dependOn(&cmd.step);
}
