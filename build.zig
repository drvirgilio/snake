const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{ .default_target = .{ .abi = .gnu } });
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("snake", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);

    exe.linkSystemLibrary("sdl2");
    exe.linkLibC();
    exe.setLibCFile(std.build.FileSource{.path="libc-paths"}); // workaround for zig issue #8144
    exe.install();
}

