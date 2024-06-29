const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const zgrad_dependency = b.dependency("zgrad", .{
        .target = target,
        .optimize = .ReleaseSafe,
    });
    const zgrad_module = zgrad_dependency.module("zgrad");

    const exe = b.addExecutable(.{
        .name = "mnist-classifier",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = .ReleaseSafe,
    });

    exe.root_module.addImport("zgrad", zgrad_module);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
