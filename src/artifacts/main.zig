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

fn resolveSource(
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

fn cacheFilePath(
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
            .{ CONTEXT.Message.ARTIFACT_CACHE_COULD_NOT_BE_WRITTEN, err },
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
            .{ CONTEXT.Message.ARTIFACT_CACHE_COULD_NOT_BE_WRITTEN, err },
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
            , .{ CONTEXT.Message.ARTIFACT_COULD_NOT_BE_LOADED, source, err }) catch
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

test "collectCreativeSources gathers creative media urls across manifests and dedupes" {
    var arena = STD.heap.ArenaAllocator.init(STD.testing.allocator);
    defer arena.deinit();
    const ALLOCATOR = arena.allocator();

    const MANIFEST_ONE = testManifest(ALLOCATOR, &.{
        "https://cdn.example.com/one.png",
        "https://cdn.example.com/two.jpg",
    });
    const MANIFEST_TWO = testManifest(ALLOCATOR, &.{
        "https://cdn.example.com/one.png",
        "https://cdn.example.com/three.jpg",
        "https://cdn.example.com/four.jpg",
    });

    const SOURCES = try collectCreativeSources(ALLOCATOR, &.{
        .{ .file_path = "one.campi", .source = "", .value = MANIFEST_ONE },
        .{ .file_path = "two.campi", .source = "", .value = MANIFEST_TWO },
    });

    try STD.testing.expectEqualSlices([]const u8, &.{
        "https://cdn.example.com/one.png",
        "https://cdn.example.com/two.jpg",
        "https://cdn.example.com/three.jpg",
        "https://cdn.example.com/four.jpg",
    }, SOURCES);
}

test "contentTypeForSource maps extensions case-insensitively" {
    const CASES = .{
        .{ "https://x.com/a.PNG", "image/png" },
        .{ "https://x.com/a.jpg", "image/jpeg" },
        .{ "https://x.com/a.JPEG", "image/jpeg" },
        .{ "https://x.com/a.webp", "image/webp" },
        .{ "https://x.com/a.GIF", "image/gif" },
        .{ "https://x.com/a.mp4", "video/mp4" },
        .{ "https://x.com/a.bin", "application/octet-stream" },
        .{ "https://x.com/a.png?token=abc", "application/octet-stream" },
    };

    inline for (CASES) |CASE| {
        try STD.testing.expectEqualStrings(CASE[1], contentTypeForSource(CASE[0]));
    }
}

test "resolveKind distinguishes remote and local sources" {
    try STD.testing.expectEqual(SCHEMA.SOURCE_KIND.remote, resolveKind("https://x.com/a.png"));
    try STD.testing.expectEqual(SCHEMA.SOURCE_KIND.remote, resolveKind("http://x.com/a.png"));
    try STD.testing.expectEqual(SCHEMA.SOURCE_KIND.local, resolveKind("creative.png"));
    try STD.testing.expectEqual(SCHEMA.SOURCE_KIND.local, resolveKind("/absolute/creative.png"));
    try STD.testing.expectEqual(SCHEMA.SOURCE_KIND.local, resolveKind("file://creative.png"));
}

test "cacheKey is deterministic and distinct per source" {
    var arena = STD.heap.ArenaAllocator.init(STD.testing.allocator);
    defer arena.deinit();
    const ALLOCATOR = arena.allocator();

    const KEY_ONE = try cacheKey(ALLOCATOR, "https://x.com/a.png");
    const KEY_ONE_AGAIN = try cacheKey(ALLOCATOR, "https://x.com/a.png");
    const KEY_TWO = try cacheKey(ALLOCATOR, "https://x.com/b.png");

    try STD.testing.expectEqualStrings(KEY_ONE, KEY_ONE_AGAIN);
    try STD.testing.expect(STD.mem.eql(u8, KEY_ONE, KEY_TWO) == false);
}

test "resolveSource downloads a remote creative over loopback http" {
    var arena = STD.heap.ArenaAllocator.init(STD.testing.allocator);
    defer arena.deinit();
    const ALLOCATOR = arena.allocator();

    var stdin_reader = STD.Io.Reader.fixed(&.{});
    var stdout_writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);
    var stderr_writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);
    const COMMAND_CONTEXT = testContext(&stdin_reader, &stdout_writer.writer, &stderr_writer.writer);

    const BODY = "fake-image-bytes";

    var address = STD.Io.net.IpAddress{ .ip4 = STD.Io.net.Ip4Address.loopback(0) };
    var server = address.listen(STD.testing.io, .{}) catch |err| switch (err) {
        error.NetworkDown => return error.SkipZigTest,
        else => return err,
    };
    defer server.deinit(STD.testing.io);

    const PORT = server.socket.address.ip4.port;

    const SERVER_THREAD = STD.Thread.spawn(.{}, serveHttp, .{ &server, BODY, STD.http.Status.ok }) catch
        return error.SkipZigTest;
    defer SERVER_THREAD.join();

    const URL = try STD.fmt.allocPrint(ALLOCATOR, "http://127.0.0.1:{d}/creative.png", .{PORT});

    const BYTES = try resolveSource(ALLOCATOR, COMMAND_CONTEXT, STD.Io.Dir.cwd(), URL);

    try STD.testing.expectEqualStrings(BODY, BYTES);
}

test "resolveSource fails when the remote responds not found" {
    var arena = STD.heap.ArenaAllocator.init(STD.testing.allocator);
    defer arena.deinit();
    const ALLOCATOR = arena.allocator();

    var stdin_reader = STD.Io.Reader.fixed(&.{});
    var stdout_writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);
    var stderr_writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);
    const COMMAND_CONTEXT = testContext(&stdin_reader, &stdout_writer.writer, &stderr_writer.writer);

    var address = STD.Io.net.IpAddress{ .ip4 = STD.Io.net.Ip4Address.loopback(0) };
    var server = address.listen(STD.testing.io, .{}) catch |err| switch (err) {
        error.NetworkDown => return error.SkipZigTest,
        else => return err,
    };
    defer server.deinit(STD.testing.io);

    const PORT = server.socket.address.ip4.port;

    const SERVER_THREAD = STD.Thread.spawn(.{}, serveHttp, .{ &server, "", STD.http.Status.not_found }) catch
        return error.SkipZigTest;
    defer SERVER_THREAD.join();

    const URL = try STD.fmt.allocPrint(ALLOCATOR, "http://127.0.0.1:{d}/missing.png", .{PORT});

    try STD.testing.expectError(error.ArtifactDownloadFailed, resolveSource(
        ALLOCATOR,
        COMMAND_CONTEXT,
        STD.Io.Dir.cwd(),
        URL,
    ));
}

test "resolveSource reads a local creative from a temp directory" {
    var arena = STD.heap.ArenaAllocator.init(STD.testing.allocator);
    defer arena.deinit();
    const ALLOCATOR = arena.allocator();

    var stdin_reader = STD.Io.Reader.fixed(&.{});
    var stdout_writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);
    var stderr_writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);
    const COMMAND_CONTEXT = testContext(&stdin_reader, &stdout_writer.writer, &stderr_writer.writer);

    var tmp = STD.testing.tmpDir(.{});
    defer tmp.cleanup();

    const FILE_NAME = "creative.png";
    try tmp.dir.writeFile(
        STD.testing.io,
        .{ .sub_path = FILE_NAME, .data = "local-image-bytes" },
    );

    const BYTES = try resolveSource(ALLOCATOR, COMMAND_CONTEXT, tmp.dir, FILE_NAME);

    try STD.testing.expectEqualStrings("local-image-bytes", BYTES);
}

test "resolveSource strips a file scheme prefix from a local source" {
    var arena = STD.heap.ArenaAllocator.init(STD.testing.allocator);
    defer arena.deinit();
    const ALLOCATOR = arena.allocator();

    var stdin_reader = STD.Io.Reader.fixed(&.{});
    var stdout_writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);
    var stderr_writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);
    const COMMAND_CONTEXT = testContext(&stdin_reader, &stdout_writer.writer, &stderr_writer.writer);

    var tmp = STD.testing.tmpDir(.{});
    defer tmp.cleanup();

    const FILE_NAME = "creative.jpg";
    try tmp.dir.writeFile(
        STD.testing.io,
        .{ .sub_path = FILE_NAME, .data = "schemed-image-bytes" },
    );

    const SOURCE = try STD.fmt.allocPrint(ALLOCATOR, "file://{s}", .{FILE_NAME});

    const BYTES = try resolveSource(ALLOCATOR, COMMAND_CONTEXT, tmp.dir, SOURCE);

    try STD.testing.expectEqualStrings("schemed-image-bytes", BYTES);
}

test "loadArtifact caches downloaded bytes on disk" {
    var arena = STD.heap.ArenaAllocator.init(STD.testing.allocator);
    defer arena.deinit();
    const ALLOCATOR = arena.allocator();

    var stdin_reader = STD.Io.Reader.fixed(&.{});
    var stdout_writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);
    var stderr_writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);
    const COMMAND_CONTEXT = testContext(&stdin_reader, &stdout_writer.writer, &stderr_writer.writer);

    var tmp = STD.testing.tmpDir(.{});
    defer tmp.cleanup();

    const FILE_NAME = "creative.png";
    try tmp.dir.writeFile(
        STD.testing.io,
        .{ .sub_path = FILE_NAME, .data = "cachable-image-bytes" },
    );

    const ARTIFACT = try loadArtifact(ALLOCATOR, COMMAND_CONTEXT, tmp.dir, FILE_NAME);

    try STD.testing.expectEqualStrings("cachable-image-bytes", ARTIFACT.bytes);
    try STD.testing.expectEqualStrings("image/png", ARTIFACT.content_type);

    const CACHE_KEY = try cacheKey(ALLOCATOR, FILE_NAME);
    const CACHE_PATH = try cacheFilePath(ALLOCATOR, CACHE_KEY);

    tmp.dir.access(
        STD.testing.io,
        CACHE_PATH,
        .{},
    ) catch |err| switch (err) {
        error.FileNotFound => return error.CacheFileMissing,
        else => return err,
    };
}

test "loadArtifact serves a warm cache even when the source vanishes" {
    var arena = STD.heap.ArenaAllocator.init(STD.testing.allocator);
    defer arena.deinit();
    const ALLOCATOR = arena.allocator();

    var stdin_reader = STD.Io.Reader.fixed(&.{});
    var stdout_writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);
    var stderr_writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);
    const COMMAND_CONTEXT = testContext(&stdin_reader, &stdout_writer.writer, &stderr_writer.writer);

    var tmp = STD.testing.tmpDir(.{});
    defer tmp.cleanup();

    const FILE_NAME = "creative.gif";
    try tmp.dir.writeFile(
        STD.testing.io,
        .{ .sub_path = FILE_NAME, .data = "warm-cache-image-bytes" },
    );

    const COLD = try loadArtifact(ALLOCATOR, COMMAND_CONTEXT, tmp.dir, FILE_NAME);
    try STD.testing.expectEqualStrings("warm-cache-image-bytes", COLD.bytes);

    tmp.dir.deleteFile(
        STD.testing.io,
        FILE_NAME,
    ) catch |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    };

    const WARM = try loadArtifact(ALLOCATOR, COMMAND_CONTEXT, tmp.dir, FILE_NAME);

    try STD.testing.expectEqualStrings("warm-cache-image-bytes", WARM.bytes);
}

test "loadArtifacts collects failures and flags the result invalid" {
    var arena = STD.heap.ArenaAllocator.init(STD.testing.allocator);
    defer arena.deinit();
    const ALLOCATOR = arena.allocator();

    var stdin_reader = STD.Io.Reader.fixed(&.{});
    var stdout_writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);
    defer stdout_writer.deinit();
    var stderr_writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);
    defer stderr_writer.deinit();
    const COMMAND_CONTEXT = testContext(&stdin_reader, &stdout_writer.writer, &stderr_writer.writer);

    var tmp = STD.testing.tmpDir(.{});
    defer tmp.cleanup();

    const FILE_NAME = "creative.webp";
    try tmp.dir.writeFile(
        STD.testing.io,
        .{ .sub_path = FILE_NAME, .data = "present-bytes" },
    );

    const RESULT = loadArtifacts(ALLOCATOR, COMMAND_CONTEXT, tmp.dir, &.{
        FILE_NAME,
        "missing-creative.gif",
    });

    try STD.testing.expectEqual(@as(usize, 1), RESULT.artifacts.len);
    try STD.testing.expectEqualStrings("present-bytes", RESULT.artifacts[0].bytes);
    try STD.testing.expectEqual(@as(usize, 1), RESULT.failed.len);
    try STD.testing.expectEqualStrings("missing-creative.gif", RESULT.failed[0]);
    try STD.testing.expect(RESULT.invalid);
}

fn serveHttp(
    server: *STD.Io.net.Server,
    body: []const u8,
    status: STD.http.Status,
) void {
    const STREAM = server.accept(STD.testing.io) catch return;
    defer STREAM.close(STD.testing.io);

    var input_buffer: [1024]u8 = undefined;
    var output_buffer: [1024]u8 = undefined;
    var reader = STREAM.reader(STD.testing.io, &input_buffer);
    var writer = STREAM.writer(STD.testing.io, &output_buffer);

    var http_server = STD.http.Server.init(&reader.interface, &writer.interface);
    var REQUEST = http_server.receiveHead() catch return;

    REQUEST.respond(body, .{ .status = status }) catch return;
}

fn testContext(
    stdin: *STD.Io.Reader,
    stdout: *STD.Io.Writer,
    stderr: *STD.Io.Writer,
) CONTEXT.CommandContext {
    return .{
        .stdin = stdin,
        .stdout = stdout,
        .stderr = stderr,
        .io = STD.testing.io,
    };
}

fn testManifest(allocator: STD.mem.Allocator, media_urls: []const []const u8) MANIFEST.SCHEMA.MANIFEST {
    const AD_GROUP_NAMES = allocator.alloc([]const u8, 1) catch unreachable;
    AD_GROUP_NAMES[0] = "Test Ad Group";

    const ADS = allocator.alloc(MANIFEST.SCHEMA.AD, 1) catch unreachable;
    ADS[0] = .{
        .name = "Test Ad",
        .status = .ACTIVE,
        .target = null,
        .CREATIVE = .{
            .media_type = .IMAGE,
            .headline = "Headline",
            .body_text = "Body",
            .call_to_action = .LEARN_MORE,
            .media_urls = media_urls,
            .destination_url = "https://x.com/landing",
            .display_url = null,
        },
        .tracking = null,
    };

    const AD_GROUPS = allocator.alloc(MANIFEST.SCHEMA.AD_GROUP, 1) catch unreachable;
    AD_GROUPS[0] = .{
        .name = AD_GROUP_NAMES,
        .status = .ACTIVE,
        .budget = null,
        .target = null,
        .optimization_goal = null,
        .bid_amount_in_cents = null,
        .ads = ADS,
    };

    const CAMPAIGNS = allocator.alloc(MANIFEST.SCHEMA.CAMPAIGN, 1) catch unreachable;
    CAMPAIGNS[0] = .{
        .name = "Test Campaign",
        .objective = .TRAFFIC,
        .status = .ACTIVE,
        .budget = null,
        .ad_groups = AD_GROUPS,
    };

    return .{
        .campaigns = CAMPAIGNS,
        .platforms = .{
            .meta = null,
            .x = null,
            .tiktok = null,
            .google = null,
            .reddit = null,
            .linkedin = null,
        },
    };
}
