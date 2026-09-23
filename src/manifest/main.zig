const STD = @import("std");

const CONFIG = @import("../config/main.zig");
const CONTEXT = @import("../cli/context.zig");

pub const SCHEMA = @import("schema.zig");

pub const LoadedManifest = struct {
    file_path: []const u8,
    source: []const u8,
    value: SCHEMA.MANIFEST,
};

pub const LoadResult = struct {
    manifests: []LoadedManifest,
    invalid: bool,
};

pub fn filePaths(context: CONTEXT.CommandContext, config: CONFIG.SCHEMA.CONFIG) ?[]const []const u8 {
    switch (config.manifest_files) {
        .globs => {
            context.stderr.print(
                \\{s}
                \\
            , .{CONTEXT.Message.Generic.NOT_IMPLEMENTED}) catch
                return null;

            return null;
        },
        .manifest_files => |files| {
            const LIST = files orelse {
                context.stderr.print(
                    \\{s}
                    \\
                , .{CONTEXT.Message.Generic.NO_MANIFEST_FILES_CONFIGURED}) catch
                    return null;

                return null;
            };

            if (LIST.len == 0) {
                context.stderr.print(
                    \\{s}
                    \\
                , .{CONTEXT.Message.Generic.NO_MANIFEST_FILES_CONFIGURED}) catch
                    return null;

                return null;
            }

            return LIST;
        },
    }
}

pub fn loadAll(
    allocator: STD.mem.Allocator,
    context: CONTEXT.CommandContext,
    work_dir: STD.Io.Dir,
    manifest_files: []const []const u8,
) LoadResult {
    var manifests = STD.ArrayList(LoadedManifest).empty;
    var invalid = false;

    for (manifest_files) |manifest_file| {
        const SOURCE = work_dir.readFileAllocOptions(
            context.io,
            manifest_file,
            allocator,
            .unlimited,
            .of(u8),
            0,
        ) catch |err| {
            context.stderr.print(
                \\{s}{s}
                \\
                \\{any}
                \\
            , .{ CONTEXT.Message.Generic.INVALID_MANIFEST, manifest_file, err }) catch
                return .{ .manifests = manifests.items, .invalid = true };

            invalid = true;
            continue;
        };

        const VALUE = STD.zon.parse.fromSliceAlloc(
            SCHEMA.MANIFEST,
            allocator,
            SOURCE,
            null,
            .{},
        ) catch |err| {
            context.stderr.print(
                \\{s}{s}
                \\
                \\{any}
                \\
            , .{ CONTEXT.Message.Generic.INVALID_MANIFEST, manifest_file, err }) catch
                return .{ .manifests = manifests.items, .invalid = true };

            invalid = true;
            continue;
        };

        context.stdout.print(
            \\{s}{s}
            \\
        , .{ CONTEXT.Message.Generic.VALID_MANIFEST, manifest_file }) catch
            return .{ .manifests = manifests.items, .invalid = true };

        manifests.append(allocator, .{
            .file_path = manifest_file,
            .source = SOURCE,
            .value = VALUE,
        }) catch return .{
            .manifests = manifests.items,
            .invalid = true,
        };
    }

    return .{
        .manifests = manifests.items,
        .invalid = invalid,
    };
}
