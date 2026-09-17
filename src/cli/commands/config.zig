const STD = @import("std");

const CONFIG = @import("../../config/main.zig");
const CONTEXT = @import("../context.zig");
const FS = @import("../../fs/main.zig");
const PARSER = @import("../parser.zig");

pub const FLAGS = [_]PARSER.FlagDefinition{
    .{
        .long_flag = "dir",
        .short_flag = 'd',
        .is_flag_a_boolean = false,
        .description = "Run command in the specified working directory",
    },
};

fn printPlatforms(
    context: CONTEXT.CommandContext,
    config: CONFIG.SCHEMA.CONFIG,
) CONTEXT.ExitCode {
    var has_printed_any = false;

    inline for (STD.meta.fields(@TypeOf(config.platform_configs))) |platform| {
        if (@field(config.platform_configs, platform.name) != null) {
            if (has_printed_any) {
                context.stdout.print(", {s}", .{platform.name}) catch
                    return CONTEXT.ExitCode.RUNTIME_FAILURE;
            } else {
                context.stdout.print("platforms: {s}", .{platform.name}) catch
                    return CONTEXT.ExitCode.RUNTIME_FAILURE;

                has_printed_any = true;
            }
        }
    }

    if (!has_printed_any) {
        context.stdout.print("platforms: none\n", .{}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.SUCCESS;
    }

    context.stdout.print("\n", .{}) catch
        return CONTEXT.ExitCode.RUNTIME_FAILURE;

    return CONTEXT.ExitCode.SUCCESS;
}

fn printManifestFiles(
    context: CONTEXT.CommandContext,
    config: CONFIG.SCHEMA.CONFIG,
) CONTEXT.ExitCode {
    switch (config.manifest_files) {
        .globs => |globs| {
            if (globs.len == 0) {
                context.stdout.print("manifest files: globs: none\n", .{}) catch
                    return CONTEXT.ExitCode.RUNTIME_FAILURE;

                return CONTEXT.ExitCode.SUCCESS;
            }

            var has_printed_any = false;

            for (globs) |glob| {
                if (has_printed_any) {
                    context.stdout.print(", {s}", .{glob}) catch
                        return CONTEXT.ExitCode.RUNTIME_FAILURE;
                } else {
                    context.stdout.print("manifest files: globs: {s}", .{glob}) catch
                        return CONTEXT.ExitCode.RUNTIME_FAILURE;

                    has_printed_any = true;
                }
            }

            context.stdout.print("\n", .{}) catch
                return CONTEXT.ExitCode.RUNTIME_FAILURE;
        },
        .manifest_files => |files| {
            const LIST = files orelse {
                context.stdout.print("manifest files: none\n", .{}) catch
                    return CONTEXT.ExitCode.RUNTIME_FAILURE;

                return CONTEXT.ExitCode.SUCCESS;
            };

            if (LIST.len == 0) {
                context.stdout.print("manifest files: none\n", .{}) catch
                    return CONTEXT.ExitCode.RUNTIME_FAILURE;

                return CONTEXT.ExitCode.SUCCESS;
            }

            var has_printed_any = false;

            for (LIST) |file_path| {
                if (has_printed_any) {
                    context.stdout.print(", {s}", .{file_path}) catch
                        return CONTEXT.ExitCode.RUNTIME_FAILURE;
                } else {
                    context.stdout.print("manifest files: {s}", .{file_path}) catch
                        return CONTEXT.ExitCode.RUNTIME_FAILURE;

                    has_printed_any = true;
                }
            }

            context.stdout.print("\n", .{}) catch
                return CONTEXT.ExitCode.RUNTIME_FAILURE;
        },
    }

    return CONTEXT.ExitCode.SUCCESS;
}

pub fn run(
    allocator: STD.mem.Allocator,
    context: CONTEXT.CommandContext,
    flags: []const PARSER.ResolvedFlagState,
) CONTEXT.ExitCode {
    var path_buffer: [STD.Io.Dir.max_path_bytes]u8 = undefined;

    const DIR_PATH = FS.dirPath(context, flags, &path_buffer) catch {
        context.stderr.print(
            \\{s}
            \\
        , .{CONTEXT.Message.COULD_NOT_DETERMINE_WORKING_DIRECTORY}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    };

    const WORK_DIR = FS.openWorkDir(context, DIR_PATH) catch {
        context.stderr.print(
            \\{s}{s}
            \\
        , .{ CONTEXT.Message.WORKING_DIRECTORY_DOES_NOT_EXIST, DIR_PATH }) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    };
    defer WORK_DIR.close(context.io);

    CONFIG.load(allocator, context, WORK_DIR) catch {
        context.stderr.print(
            \\{s}
            \\
        , .{CONTEXT.Message.CONFIG_NOT_FOUND}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    };

    const CURRENT_CONFIG = CONFIG.current_config.?;

    context.stdout.print("config file: {s}/config.campi\n", .{DIR_PATH}) catch
        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    context.stdout.print("config version: {s}\n", .{CURRENT_CONFIG.config_version}) catch
        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    context.stdout.print("campi version: {s}\n", .{CURRENT_CONFIG.campi_version}) catch
        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    context.stdout.print("project name: {s}\n", .{CURRENT_CONFIG.project_name}) catch
        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    context.stdout.print(
        "state file: {s} {s}\n",
        .{ @tagName(CURRENT_CONFIG.state_file_location_type), CURRENT_CONFIG.state_file_uri },
    ) catch return CONTEXT.ExitCode.RUNTIME_FAILURE;

    if (printPlatforms(context, CURRENT_CONFIG) != CONTEXT.ExitCode.SUCCESS)
        return CONTEXT.ExitCode.RUNTIME_FAILURE;

    if (printManifestFiles(context, CURRENT_CONFIG) != CONTEXT.ExitCode.SUCCESS)
        return CONTEXT.ExitCode.RUNTIME_FAILURE;

    return CONTEXT.ExitCode.SUCCESS;
}
