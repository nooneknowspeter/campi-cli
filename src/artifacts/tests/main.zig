const STD = @import("std");

const CONTEXT = @import("../../cli/context.zig");
const MANIFEST = @import("../../manifest/main.zig");
const MODULE = @import("../main.zig");

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

    const SOURCES = try MODULE.collectCreativeSources(ALLOCATOR, &.{
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
        try STD.testing.expectEqualStrings(CASE[1], MODULE.contentTypeForSource(CASE[0]));
    }
}

test "resolveKind distinguishes remote and local sources" {
    try STD.testing.expectEqual(MODULE.SCHEMA.SOURCE_KIND.remote, MODULE.resolveKind("https://x.com/a.png"));
    try STD.testing.expectEqual(MODULE.SCHEMA.SOURCE_KIND.remote, MODULE.resolveKind("http://x.com/a.png"));
    try STD.testing.expectEqual(MODULE.SCHEMA.SOURCE_KIND.local, MODULE.resolveKind("creative.png"));
    try STD.testing.expectEqual(MODULE.SCHEMA.SOURCE_KIND.local, MODULE.resolveKind("/absolute/creative.png"));
    try STD.testing.expectEqual(MODULE.SCHEMA.SOURCE_KIND.local, MODULE.resolveKind("file://creative.png"));
}

test "cacheKey is deterministic and distinct per source" {
    var arena = STD.heap.ArenaAllocator.init(STD.testing.allocator);
    defer arena.deinit();
    const ALLOCATOR = arena.allocator();

    const KEY_ONE = try MODULE.cacheKey(ALLOCATOR, "https://x.com/a.png");
    const KEY_ONE_AGAIN = try MODULE.cacheKey(ALLOCATOR, "https://x.com/a.png");
    const KEY_TWO = try MODULE.cacheKey(ALLOCATOR, "https://x.com/b.png");

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

    const BYTES = try MODULE.resolveSource(ALLOCATOR, COMMAND_CONTEXT, STD.Io.Dir.cwd(), URL);

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

    try STD.testing.expectError(error.ArtifactDownloadFailed, MODULE.resolveSource(
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

    const BYTES = try MODULE.resolveSource(ALLOCATOR, COMMAND_CONTEXT, tmp.dir, FILE_NAME);

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

    const BYTES = try MODULE.resolveSource(ALLOCATOR, COMMAND_CONTEXT, tmp.dir, SOURCE);

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

    const ARTIFACT = try MODULE.loadArtifact(ALLOCATOR, COMMAND_CONTEXT, tmp.dir, FILE_NAME);

    try STD.testing.expectEqualStrings("cachable-image-bytes", ARTIFACT.bytes);
    try STD.testing.expectEqualStrings("image/png", ARTIFACT.content_type);

    const CACHE_KEY = try MODULE.cacheKey(ALLOCATOR, FILE_NAME);
    const CACHE_PATH = try MODULE.cacheFilePath(ALLOCATOR, CACHE_KEY);

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

    const COLD = try MODULE.loadArtifact(ALLOCATOR, COMMAND_CONTEXT, tmp.dir, FILE_NAME);
    try STD.testing.expectEqualStrings("warm-cache-image-bytes", COLD.bytes);

    tmp.dir.deleteFile(
        STD.testing.io,
        FILE_NAME,
    ) catch |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    };

    const WARM = try MODULE.loadArtifact(ALLOCATOR, COMMAND_CONTEXT, tmp.dir, FILE_NAME);

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

    const RESULT = MODULE.loadArtifacts(ALLOCATOR, COMMAND_CONTEXT, tmp.dir, &.{
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
