const std = @import("std");
const builtin = @import("builtin");
const VER = @import("version.zig").version;

fn saveVersion(vv: std.SemanticVersion) !void {
    const file = try std.fs.cwd().createFile("version.zig", .{ .truncate = true });
    defer file.close();

    const content = 
        \\const std = @import("std");
        \\pub const version: std.SemanticVersion = .{{
        \\    .major = {d},
        \\    .minor = {d},
        \\    .patch = {d},
        \\}};
        \\
    ;

    const formatted_content = try std.fmt.allocPrint(
        std.heap.page_allocator,
        content,
        .{ vv.major, vv.minor, vv.patch },
    );
    defer std.heap.page_allocator.free(formatted_content);
    try file.writeAll(formatted_content);
    std.debug.print("Saved version to version.zig: {}.{}.{}\n", .{
        vv.major, vv.minor, vv.patch,
    });
}

pub fn build(b: *std.Build) void {
    var vv = VER;
    const major = b.option(bool, "major", "increment major") orelse false;
    if (major) {
        vv.major += 1;
        vv.minor = 0;
        vv.patch = 0;
        saveVersion(vv) catch |err| {
            std.debug.print("Failed to save version: {}\n", .{err});
        };
    } else {
        const minor = b.option(bool, "minor", "increment minor") orelse false;
        if (minor) {
            vv.minor += 1;
            vv.patch = 0;
            saveVersion(vv) catch |err| {
                std.debug.print("Failed to save version: {}\n", .{err});
            };
        } else {
            const patch = b.option(bool, "patch", "increment patch") orelse false;
            if (patch) {
                vv.patch += 1;
                saveVersion(vv) catch |err| {
                    std.debug.print("Failed to save version: {}\n", .{err});
                };
            }
        }
    }

    std.debug.print("Building zigma version {}.{}.{}\n", .{
        vv.major, vv.minor, vv.patch,
    });

    const exe = b.addExecutable(.{
        .name = "zigma",
        .root_source_file = b.path("zigma.zig"),
        .target = b.graph.host,
        .optimize = .Debug, // .ReleaseSafe,
        .version = vv,
    });

    b.installArtifact(exe);
    const run_arti = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the executable");
    run_step.dependOn(&run_arti.step);

    const test_exe = b.addTest(.{
        .name = "unit_tests",
        .root_source_file = b.path("zigma.zig"),
        .target = b.graph.host,
        .optimize = .Debug, // .ReleaseSafe,
    });
    b.installArtifact(test_exe);
    const test_arti = b.addRunArtifact(test_exe);
    const test_step = b.step("test", "Run the tests");
    test_step.dependOn(&test_arti.step);
}
