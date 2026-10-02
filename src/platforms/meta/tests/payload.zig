const STD = @import("std");

const MANIFEST = @import("../../../manifest/schema.zig");
const MODULE = @import("../payload.zig");

test "campaign payload maps objective and budget" {
    var arena = STD.heap.ArenaAllocator.init(STD.testing.allocator);
    defer arena.deinit();
    const ALLOCATOR = arena.allocator();

    const CAMPAIGN = MANIFEST.CAMPAIGN{
        .name = "Spring Sale",
        .objective = .TRAFFIC,
        .status = .ACTIVE,
        .budget = .{ .type = .DAILY, .amount_in_cents = 10000, .currency = "USD" },
        .ad_groups = &.{},
    };

    const PAYLOAD = try MODULE.campaignPayload(ALLOCATOR, CAMPAIGN);

    try STD.testing.expectEqualStrings(
        "{\"name\":\"Spring Sale\",\"objective\":\"OUTCOME_TRAFFIC\",\"status\":\"ACTIVE\",\"special_ad_categories\":[],\"daily_budget\":\"10000\"}",
        PAYLOAD,
    );
}

test "campaign payload reports ad set budget sharing when no campaign budget is set" {
    var arena = STD.heap.ArenaAllocator.init(STD.testing.allocator);
    defer arena.deinit();
    const ALLOCATOR = arena.allocator();

    const CAMPAIGN = MANIFEST.CAMPAIGN{
        .name = "Housing Push",
        .objective = .LEADS,
        .status = .PAUSED,
        .budget = null,
        .special_ad_categories = &.{.HOUSING},
        .ad_groups = &.{},
    };

    const PAYLOAD = try MODULE.campaignPayload(ALLOCATOR, CAMPAIGN);

    try STD.testing.expectEqualStrings(
        "{\"name\":\"Housing Push\",\"objective\":\"OUTCOME_LEADS\",\"status\":\"PAUSED\",\"special_ad_categories\":[\"HOUSING\"],\"is_adset_budget_sharing_enabled\":false}",
        PAYLOAD,
    );
}

test "creative payload embeds the image hash and call to action" {
    var arena = STD.heap.ArenaAllocator.init(STD.testing.allocator);
    defer arena.deinit();
    const ALLOCATOR = arena.allocator();

    const AD = MANIFEST.AD{
        .name = "Spring Ad",
        .status = .ACTIVE,
        .target = null,
        .CREATIVE = .{
            .media_type = .IMAGE,
            .headline = "Headline",
            .body_text = "Body",
            .call_to_action = .SIGN_UP,
            .media_urls = &.{"https://cdn.example.com/ad.png"},
            .destination_url = "https://campi.example.com/landing",
            .display_url = null,
        },
        .tracking = null,
    };

    const PAYLOAD = try MODULE.creativePayload(ALLOCATOR, .{ .page_id = "123456789" }, AD, "abc123");

    try STD.testing.expectEqualStrings(
        "{\"name\":\"Spring Ad\",\"object_story_spec\":{\"type\":\"link\",\"page_id\":\"123456789\",\"link_data\":{\"link\":\"https://campi.example.com/landing\",\"name\":\"Headline\",\"message\":\"Body\",\"image_hash\":\"abc123\",\"call_to_action\":{\"type\":\"SIGN_UP\"}}}}",
        PAYLOAD,
    );
}

test "creative payload targets instagram when no page id is given" {
    var arena = STD.heap.ArenaAllocator.init(STD.testing.allocator);
    defer arena.deinit();
    const ALLOCATOR = arena.allocator();

    const AD = MANIFEST.AD{
        .name = "Spring Ad",
        .status = .ACTIVE,
        .target = null,
        .CREATIVE = .{
            .media_type = .IMAGE,
            .headline = "Headline",
            .body_text = "Body",
            .call_to_action = .SIGN_UP,
            .media_urls = &.{"https://cdn.example.com/ad.png"},
            .destination_url = "https://campi.example.com/landing",
            .display_url = null,
        },
        .tracking = null,
    };

    const PAYLOAD = try MODULE.creativePayload(
        ALLOCATOR,
        .{ .instagram_actor_id = "987654321" },
        AD,
        "abc123",
    );

    try STD.testing.expectEqualStrings(
        "{\"name\":\"Spring Ad\",\"object_story_spec\":{\"type\":\"link\",\"instagram_actor_id\":\"987654321\",\"link_data\":{\"link\":\"https://campi.example.com/landing\",\"name\":\"Headline\",\"message\":\"Body\",\"image_hash\":\"abc123\",\"call_to_action\":{\"type\":\"SIGN_UP\"}}}}",
        PAYLOAD,
    );
}
