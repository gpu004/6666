const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});
    const exe = b.addExecutable(.{
        .name = "tb_checksum",
        .root_module = b.createModule(.{
            .root_source_file = b.path("ocaml_tb_checksum.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.addImport("stdx", b.createModule(.{
        .root_source_file = b.path("../repo/src/stdx/stdx.zig"),
        .target = target,
        .optimize = optimize,
    }));
    b.installArtifact(exe);
}
