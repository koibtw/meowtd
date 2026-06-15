const std = @import("std");
const fmt = std.fmt;

const Build = std.Build;
const Module = Build.Module;
const ResolvedTarget = Build.ResolvedTarget;
const OptimizeMode = std.builtin.OptimizeMode;

const Error = std.mem.Allocator.Error;

const Self = @This();

b: *Build,
target: ResolvedTarget,
optimize: OptimizeMode,

pub fn build(b: *Build) Error!void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    var self: Self = .{ .b = b, .target = target, .optimize = optimize };

    try self.exe("meowtd-receive", self.mod("src/receive/main.zig"));
}

fn mod(self: *Self, comptime path: []const u8) *Module {
    const b = self.b;

    return b.createModule(.{
        .root_source_file = b.path(path),
        .target = self.target,
        .optimize = self.optimize,
    });
}

fn exe(self: *Self, comptime name: []const u8, root_module: *Module) Error!void {
    const b = self.b;
    const allocator = b.allocator;

    const e = b.addExecutable(.{ .name = name, .root_module = root_module });
    b.installArtifact(e);

    const cmd = b.addRunArtifact(e);
    cmd.step.dependOn(b.getInstallStep());
    if (b.args) |a| cmd.addArgs(a);

    const step_name = try fmt.allocPrint(allocator, "run-{s}", .{name});
    const step_description = try fmt.allocPrint(allocator, "compile and run {s}", .{name});

    const step = b.step(step_name, step_description);
    step.dependOn(&cmd.step);
}
