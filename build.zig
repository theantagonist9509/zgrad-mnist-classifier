const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const zgrad_dependency = b.dependency("zgrad", .{
        .target = target,
        .optimize = .ReleaseSafe,
    });
    const zgrad_module = zgrad_dependency.module("zgrad");

    const train = b.addExecutable(.{
        .name = "train",
        .root_source_file = .{ .path = "src/train.zig" },
        .target = target,
        .optimize = .ReleaseSafe,
    });

    train.root_module.addImport("zgrad", zgrad_module);

    b.installArtifact(train);

    const train_run_cmd = b.addRunArtifact(train);

    const train_run_step = b.step("train", "Train the classifier");
    train_run_step.dependOn(&train_run_cmd.step);

    const interact = b.addExecutable(.{
        .name = "interact",
        .root_source_file = b.path("src/interact.zig"),
        .target = target,
    });

    interact.root_module.addImport("zgrad", zgrad_module);
    interact.addCSourceFile(.{ .file = b.path("deps/src/raygui_implementation.c") });

    inline for (.{
        "raylib",
        "GL",
        "m",
        "pthread",
        "dl",
        "rt",
        "X11",
    }) |name|
        interact.linkSystemLibrary(name);

    // Change these to suit your needs
    const include_path = "/home/tejas/local/include";
    const library_path = "/home/tejas/local/lib";
    interact.addIncludePath(std.Build.LazyPath{ .path = include_path });
    interact.addLibraryPath(std.Build.LazyPath{ .path = library_path });
    interact.addRPath(std.Build.LazyPath{ .path = library_path });

    b.installArtifact(interact);

    const interact_run_cmd = b.addRunArtifact(interact);

    const interact_run_step = b.step("interact", "Interact with the classifier");
    interact_run_step.dependOn(&interact_run_cmd.step);
}
