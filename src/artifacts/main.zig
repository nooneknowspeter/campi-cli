const STD = @import("std");

const CONTEXT = @import("../cli/context.zig");
const MANIFEST = @import("../manifest/main.zig");

pub const SCHEMA = @import("schema.zig");

pub const CACHE_RELATIVE_PATH = ".campi/artifacts";

const CONTENT_KIND = enum {
    png,
    jpg,
    jpeg,
    webp,
    gif,
    mp4,
    other,
};

fn endsWithIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    if (haystack.len < needle.len) return false;

    return STD.ascii.eqlIgnoreCase(haystack[haystack.len - needle.len ..], needle);
}

fn contentKindOf(source: []const u8) CONTENT_KIND {
    if (endsWithIgnoreCase(source, ".png"))
        return .png;
    if (endsWithIgnoreCase(source, ".jpg"))
        return .jpg;
    if (endsWithIgnoreCase(source, ".jpeg"))
        return .jpeg;
    if (endsWithIgnoreCase(source, ".webp"))
        return .webp;
    if (endsWithIgnoreCase(source, ".gif"))
        return .gif;
    if (endsWithIgnoreCase(source, ".mp4"))
        return .mp4;

    return .other;
}

pub fn contentTypeForSource(source: []const u8) []const u8 {
    switch (contentKindOf(source)) {
        .png => return "image/png",
        .jpg, .jpeg => return "image/jpeg",
        .webp => return "image/webp",
        .gif => return "image/gif",
        .mp4 => return "video/mp4",
        .other => return "application/octet-stream",
    }
}

pub fn collectCreativeSources(
    allocator: STD.mem.Allocator,
    loaded_manifests: []const MANIFEST.LoadedManifest,
) ![]const []const u8 {
    var sources = STD.ArrayList([]const u8).empty;

    for (loaded_manifests) |loaded_manifest| {
        for (loaded_manifest.value.campaigns) |campaign| {
            for (campaign.ad_groups) |ad_group| {
                for (ad_group.ads) |ad| {
                    for (ad.CREATIVE.media_urls) |url| {
                        var already_known = false;

                        for (sources.items) |existing| {
                            if (STD.mem.eql(u8, existing, url)) {
                                already_known = true;
                                break;
                            }
                        }

                        if (already_known)
                            continue;

                        try sources.append(allocator, url);
                    }
                }
            }
        }
    }

    return try sources.toOwnedSlice(allocator);
}

pub fn resolveKind(source: []const u8) SCHEMA.SOURCE_KIND {
    if (STD.mem.startsWith(u8, source, "http://") or
        STD.mem.startsWith(u8, source, "https://"))
    {
        return .remote;
    }

    return .local;
}

pub fn cacheKey(allocator: STD.mem.Allocator, source: []const u8) ![]const u8 {
    var hasher = STD.hash.Wyhash.init(0);
    hasher.update(source);

    const SUM = hasher.final();

    return STD.fmt.allocPrint(allocator, "{x}", .{SUM});
}

fn sourcePath(source: []const u8) []const u8 {
    if (STD.mem.startsWith(u8, source, "file://"))
        return source["file://".len..];

    return source;
}

fn readLocalSource(
    allocator: STD.mem.Allocator,
    context: CONTEXT.CommandContext,
    work_dir: STD.Io.Dir,
    local_path: []const u8,
) ![]const u8 {
    if (STD.Io.Dir.path.isAbsolute(local_path)) {
        var file = try STD.Io.Dir.openFileAbsolute(context.io, local_path, .{});
        defer file.close(context.io);

        var reader = file.reader(context.io, &.{});

        return reader.interface.allocRemaining(allocator, .unlimited);
    }

    return work_dir.readFileAllocOptions(
        context.io,
        local_path,
        allocator,
        .unlimited,
        .of(u8),
        0,
    );
}

fn downloadSource(
    allocator: STD.mem.Allocator,
    context: CONTEXT.CommandContext,
    url: []const u8,
) ![]const u8 {
    var client = STD.http.Client{ .allocator = allocator, .io = context.io };
    defer client.deinit();

    var writer = STD.Io.Writer.Allocating.init(allocator);
    defer writer.deinit();

    const RESULT = try client.fetch(.{
        .location = .{ .url = url },
        .response_writer = &writer.writer,
    });

    if (RESULT.status.class() != .success)
        return error.ArtifactDownloadFailed;

    return try writer.toOwnedSlice();
}

pub fn resolveSource(
    allocator: STD.mem.Allocator,
    context: CONTEXT.CommandContext,
    work_dir: STD.Io.Dir,
    source: []const u8,
) ![]const u8 {
    switch (resolveKind(source)) {
        .remote => return downloadSource(allocator, context, source),
        .local => return readLocalSource(allocator, context, work_dir, sourcePath(source)),
    }
}

pub fn cacheFilePath(
    allocator: STD.mem.Allocator,
    cache_key: []const u8,
) ![]const u8 {
    return STD.fmt.allocPrint(allocator, "{s}/{s}.bin", .{ CACHE_RELATIVE_PATH, cache_key });
}

fn readCached(
    allocator: STD.mem.Allocator,
    context: CONTEXT.CommandContext,
    work_dir: STD.Io.Dir,
    cache_path: []const u8,
) !?[]const u8 {
    var file = work_dir.openFile(
        context.io,
        cache_path,
        .{},
    ) catch |err| {
        switch (err) {
            error.FileNotFound => return null,
            else => return err,
        }
    };
    defer file.close(context.io);

    var reader = file.reader(context.io, &.{});

    return try reader.interface.allocRemaining(allocator, .unlimited);
}

fn writeCache(
    context: CONTEXT.CommandContext,
    work_dir: STD.Io.Dir,
    cache_path: []const u8,
    bytes: []const u8,
) void {
    work_dir.createDirPath(context.io, CACHE_RELATIVE_PATH) catch |err| {
        context.stderr.print(
            \\{s}{any}
            \\
        ,
            .{ CONTEXT.Message.Generic.ARTIFACT_CACHE_COULD_NOT_BE_WRITTEN, err },
        ) catch {};

        return;
    };

    work_dir.writeFile(context.io, .{
        .sub_path = cache_path,
        .data = bytes,
    }) catch |err| {
        context.stderr.print(
            \\{s}{any}
            \\
        ,
            .{ CONTEXT.Message.Generic.ARTIFACT_CACHE_COULD_NOT_BE_WRITTEN, err },
        ) catch {};
    };
}

pub fn loadArtifact(
    allocator: STD.mem.Allocator,
    context: CONTEXT.CommandContext,
    work_dir: STD.Io.Dir,
    source: []const u8,
) !SCHEMA.DownloadedArtifact {
    const CACHE_KEY = try cacheKey(allocator, source);
    const CACHE_PATH = try cacheFilePath(allocator, CACHE_KEY);

    if (try readCached(allocator, context, work_dir, CACHE_PATH)) |BYTES| {
        return .{
            .source = source,
            .content_type = contentTypeForSource(source),
            .bytes = BYTES,
        };
    }

    const BYTES = try resolveSource(allocator, context, work_dir, source);

    writeCache(context, work_dir, CACHE_PATH, BYTES);

    return .{
        .source = source,
        .content_type = contentTypeForSource(source),
        .bytes = BYTES,
    };
}

pub fn loadArtifacts(
    allocator: STD.mem.Allocator,
    context: CONTEXT.CommandContext,
    work_dir: STD.Io.Dir,
    sources: []const []const u8,
) SCHEMA.ARTIFACT_RESULT {
    var artifacts = STD.ArrayList(SCHEMA.DownloadedArtifact).empty;
    var failed = STD.ArrayList([]const u8).empty;
    var invalid = false;

    for (sources) |source| {
        const ARTIFACT = loadArtifact(
            allocator,
            context,
            work_dir,
            source,
        ) catch |err| {
            context.stderr.print(
                \\{s}{s}
                \\
                \\{any}
                \\
            , .{ CONTEXT.Message.Generic.ARTIFACT_COULD_NOT_BE_LOADED, source, err }) catch
                return .{ .artifacts = artifacts.items, .failed = failed.items, .invalid = true };

            failed.append(allocator, source) catch
                return .{ .artifacts = artifacts.items, .failed = failed.items, .invalid = true };

            invalid = true;
            continue;
        };

        artifacts.append(allocator, ARTIFACT) catch
            return .{ .artifacts = artifacts.items, .failed = failed.items, .invalid = true };
    }

    return .{ .artifacts = artifacts.items, .failed = failed.items, .invalid = invalid };
}

test {
    _ = @import("tests/main.zig");
}
