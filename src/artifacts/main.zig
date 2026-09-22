const STD = @import("std");

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