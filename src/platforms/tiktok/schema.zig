const STD = @import("std");

pub const CAMPAIGN = struct {
    id: []const u8,
    name: []const u8,
    status: []const u8,
    objective: []const u8,
};

pub const AD_GROUP = struct {
    id: []const u8,
    name: []const u8,
    campaign_id: []const u8,
    status: []const u8,
};

pub const AD = struct {
    id: []const u8,
    name: []const u8,
    adgroup_id: []const u8,
    status: []const u8,
};

pub const INSIGHTS = struct {
    reach: u64 = 0,
    impressions: u64 = 0,
    clicks: u64 = 0,
    spend_cents: u64 = 0,
};

fn parseIdNumber(value: STD.json.Value) ?STD.json.Value {
    return switch (value) {
        .integer => |integer| STD.json.Value{ .integer = integer },
        .float => |float| STD.json.Value{ .integer = @intFromFloat(float) },
        .string => blk: {
            const NUMBER = STD.fmt.parseInt(u64, value.string, 10) catch
                break :blk null;

            break :blk STD.json.Value{ .integer = NUMBER };
        },
        else => null,
    };
}

fn numberValue(value: ?STD.json.Value) ?u64 {
    const VALUE = value orelse return null;

    const NUMBER = parseIdNumber(VALUE) orelse return null;

    return switch (NUMBER) {
        .integer => |integer| @intCast(integer),
        else => null,
    };
}

pub fn decodeCampaigns(
    allocator: STD.mem.Allocator,
    document: []const u8,
) !?[]CAMPAIGN {
    const PARSED = try STD.json.parseFromSlice(
        STD.json.Value,
        allocator,
        document,
        .{},
    );
    defer PARSED.deinit();

    const ROOT = PARSED.value;
    const DATA = ROOT.object.get("data") orelse return null;

    const ITEMS = try allocator.alloc(CAMPAIGN, DATA.array.items.len);

    for (DATA.array.items, 0..) |item, i| {
        const OBJECT = item.object;

        ITEMS[i] = .{
            .id = try allocator.dupe(u8, OBJECT.get("id").?.string),
            .name = try allocator.dupe(u8, OBJECT.get("name").?.string),
            .status = try allocator.dupe(u8, OBJECT.get("status").?.string),
            .objective = try allocator.dupe(
                u8,
                OBJECT.get("objective").?.string,
            ),
        };
    }

    return ITEMS;
}
