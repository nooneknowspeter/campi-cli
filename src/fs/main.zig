const STD = @import("std");

const CONFIG = @import("../config/main.zig");
const CONTEXT = @import("../cli/context.zig");
const PARSER = @import("../cli/parser.zig");

const CONFIG_FILENAME = "config.campi.zon";
const MANIFEST_EXAMPLE_FILENAME = "example.manifest.campi.zon";

pub fn dirPath(
    context: CONTEXT.CommandContext,
    flags: []const PARSER.ResolvedFlagState,
    buffer: []u8,
) ![]const u8 {
    if (PARSER.flagValue(flags, "dir")) |dir_path| {
        return dir_path;
    }

    const LENGTH = try STD.process.currentPath(context.io, buffer);

    return buffer[0..LENGTH];
}

pub fn openWorkDir(
    context: CONTEXT.CommandContext,
    dir_path: []const u8,
) STD.Io.Dir.OpenError!STD.Io.Dir {
    if (STD.Io.Dir.path.isAbsolute(dir_path)) {
        return STD.Io.Dir.openDirAbsolute(context.io, dir_path, .{});
    }

    return STD.Io.Dir.openDir(STD.Io.Dir.cwd(), context.io, dir_path, .{});
}

pub fn writeFiles(
    context: CONTEXT.CommandContext,
    work_dir: STD.Io.Dir,
    project_name: []const u8,
) !void {
    var config_buffer: [1024]u8 = undefined;

    var config_file = try work_dir.createFile(context.io, CONFIG_FILENAME, .{
        .exclusive = true,
    });
    defer config_file.close(context.io);

    var config_writer = config_file.writer(context.io, &config_buffer);
    try STD.zon.stringify.serialize(
        CONFIG.defaultConfig(project_name),
        .{ .whitespace = true },
        &config_writer.interface,
    );
    try config_writer.flush();

    try work_dir.writeFile(context.io, .{
        .sub_path = MANIFEST_EXAMPLE_FILENAME,
        .data = @embedFile("../manifest/examples/manifest.example.zon"),
        .flags = .{ .exclusive = true },
    });
}
