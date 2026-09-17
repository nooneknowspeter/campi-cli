const STD = @import("std");

const CONFIG = @import("../../config/main.zig");
const CONTEXT = @import("../context.zig");
const FS = @import("../../fs/main.zig");
const MANIFEST = @import("../../manifest/main.zig");
const PARSER = @import("../parser.zig");

pub const FLAGS = [_]PARSER.FlagDefinition{
    .{
        .long_flag = "write",
        .short_flag = 'w',
        .is_flag_a_boolean = true,
        .description = "Write the reformatted output",
    },
    .{
        .long_flag = "lsp",
        .short_flag = null,
        .is_flag_a_boolean = true,
        .description = "Run as a language server",
    },
    .{
        .long_flag = "dir",
        .short_flag = 'd',
        .is_flag_a_boolean = false,
        .description = "Run command in the specified working directory",
    },
};

const PendingWrite = struct {
    file_path: []const u8,
    contents: []const u8,
};

fn serializeManifest(value: MANIFEST.SCHEMA.MANIFEST, writer: *STD.Io.Writer) !void {
    @setEvalBranchQuota(1_000_000);

    return STD.zon.stringify.serialize(value, .{ .whitespace = true }, writer);
}

pub fn run(
    allocator: STD.mem.Allocator,
    context: CONTEXT.CommandContext,
    flags: []const PARSER.ResolvedFlagState,
) CONTEXT.ExitCode {
    if (PARSER.hasFlag(flags, "lsp")) {
        context.stderr.print(
            \\{s}
            \\
        , .{CONTEXT.Message.NOT_IMPLEMENTED}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.RUNTIME_FAILURE;
    }

    const WRITE_FILES = PARSER.hasFlag(flags, "write");

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

    const MANIFEST_FILE_PATHS = MANIFEST.filePaths(context, CONFIG.current_config.?) orelse
        return CONTEXT.ExitCode.RUNTIME_FAILURE;

    const LOADED = MANIFEST.loadAll(allocator, context, WORK_DIR, MANIFEST_FILE_PATHS);

    if (LOADED.invalid) return CONTEXT.ExitCode.RUNTIME_FAILURE;

    var recently_formatted_manifests: usize = 0;
    var pending_writes = STD.ArrayList(PendingWrite).empty;

    for (LOADED.manifests) |loaded_manifest| {
        var formatted_writer = STD.Io.Writer.Allocating.init(allocator);

        serializeManifest(loaded_manifest.value, &formatted_writer.writer) catch |err| {
            context.stderr.print(
                \\{s}{s}
                \\
                \\{any}
                \\
            , .{ CONTEXT.Message.INVALID_MANIFEST, loaded_manifest.file_path, err }) catch
                return CONTEXT.ExitCode.RUNTIME_FAILURE;

            return CONTEXT.ExitCode.RUNTIME_FAILURE;
        };

        const formatted_list = formatted_writer.toArrayList();

        if (STD.mem.eql(u8, formatted_list.items, loaded_manifest.source)) continue;

        recently_formatted_manifests += 1;

        if (WRITE_FILES) {
            pending_writes.append(allocator, .{
                .file_path = loaded_manifest.file_path,
                .contents = formatted_list.items,
            }) catch return CONTEXT.ExitCode.RUNTIME_FAILURE;

            continue;
        }

        context.stdout.print("would format: {s}\n", .{loaded_manifest.file_path}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;
    }

    if (WRITE_FILES) {
        for (pending_writes.items) |pending_write| {
            WORK_DIR.writeFile(context.io, .{
                .sub_path = pending_write.file_path,
                .data = pending_write.contents,
            }) catch |err| {
                context.stderr.print(
                    \\{s}{s}
                    \\
                    \\{any}
                    \\
                , .{ CONTEXT.Message.MANIFEST_COULD_NOT_BE_WRITTEN, pending_write.file_path, err }) catch
                    return CONTEXT.ExitCode.RUNTIME_FAILURE;

                return CONTEXT.ExitCode.RUNTIME_FAILURE;
            };

            context.stdout.print("formatted: {s}\n", .{pending_write.file_path}) catch
                return CONTEXT.ExitCode.RUNTIME_FAILURE;
        }
    }

    if (recently_formatted_manifests == 0) {
        context.stdout.print("all manifest files are already formatted\n", .{}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.SUCCESS;
    }

    if (WRITE_FILES) {
        context.stdout.print("formatted {d} manifest file(s)\n", .{recently_formatted_manifests}) catch
            return CONTEXT.ExitCode.RUNTIME_FAILURE;

        return CONTEXT.ExitCode.SUCCESS;
    }

    context.stdout.print("dry run: would format {d} manifest file(s)\n", .{recently_formatted_manifests}) catch
        return CONTEXT.ExitCode.RUNTIME_FAILURE;

    return CONTEXT.ExitCode.PENDING_UPDATES;
}
