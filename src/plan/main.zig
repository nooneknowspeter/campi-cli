const STD = @import("std");

const CONFIG = @import("../config/main.zig");
const MANIFEST = @import("../manifest/main.zig");
const STATE = @import("../state/main.zig");
const TREE = @import("../render/tree.zig");

pub const SCHEMA = @import("schema.zig");

const DesiredCampaign = struct {
    value: MANIFEST.SCHEMA.CAMPAIGN,
    input_manifest: []const u8,
};

pub fn computePlan(
    allocator: STD.mem.Allocator,
    config: CONFIG.SCHEMA.CONFIG,
    loaded_manifests: []const MANIFEST.LoadedManifest,
    recorded_state: ?STATE.SCHEMA.STATE,
) !SCHEMA.PLAN {
    var operations = STD.ArrayList(SCHEMA.OPERATION).empty;
    var unconfigured_platforms = STD.ArrayList([]const u8).empty;
    const BASE_STATE = recorded_state orelse STATE.EMPTY_STATE;

    inline for (STD.meta.fields(@TypeOf(config.platform_configs))) |platform| {
        if (@field(config.platform_configs, platform.name) != null) {
            var desired = STD.ArrayList(DesiredCampaign).empty;

            for (loaded_manifests) |loaded_manifest| {
                if (@field(loaded_manifest.value.platforms, platform.name) != true) continue;

                for (loaded_manifest.value.campaigns) |campaign| {
                    var already_desired = false;

                    for (desired.items) |existing| {
                        if (STD.mem.eql(u8, existing.value.name, campaign.name)) {
                            already_desired = true;
                            break;
                        }
                    }

                    if (already_desired) continue;

                    try desired.append(allocator, .{
                        .value = campaign,
                        .input_manifest = loaded_manifest.file_path,
                    });
                }
            }

            var recorded = STD.ArrayList(STATE.SCHEMA.CAMPAIGN).empty;

            if (@field(BASE_STATE.platforms, platform.name)) |campaigns|
                for (campaigns) |campaign|
                    try recorded.append(allocator, campaign);

            for (desired.items) |desired_campaign| {
                const HASH = try fingerprint(allocator, desired_campaign.value);

                var index: ?usize = null;

                for (recorded.items, 0..) |record, recorded_index| {
                    if (STD.mem.eql(u8, record.campaign, desired_campaign.value.name)) {
                        index = recorded_index;
                        break;
                    }
                }

                if (index) |i| {
                    const RECORD = recorded.orderedRemove(i);

                    if (!STD.mem.eql(u8, RECORD.manifest_hash, HASH)) {
                        try operations.append(allocator, .{
                            .platform = platform.name,
                            .campaign = desired_campaign.value.name,
                            .operation_type = .update,
                            .external_id = RECORD.external_id,
                            .input_manifest = desired_campaign.input_manifest,
                            .manifest_hash = HASH,
                        });
                    }
                } else {
                    try operations.append(allocator, .{
                        .platform = platform.name,
                        .campaign = desired_campaign.value.name,
                        .operation_type = .create,
                        .external_id = null,
                        .input_manifest = desired_campaign.input_manifest,
                        .manifest_hash = HASH,
                    });
                }
            }

            for (recorded.items) |record| {
                try operations.append(allocator, .{
                    .platform = platform.name,
                    .campaign = record.campaign,
                    .operation_type = .archive,
                    .external_id = record.external_id,
                    .input_manifest = record.input_manifest,
                    .manifest_hash = "",
                });
            }
        } else {
            for (loaded_manifests) |loaded_manifest| {
                if (@field(loaded_manifest.value.platforms, platform.name) != true) continue;

                try unconfigured_platforms.append(allocator, platform.name);

                break;
            }
        }
    }

    return .{
        .operations = try operations.toOwnedSlice(allocator),
        .unconfigured_platforms = try unconfigured_platforms.toOwnedSlice(allocator),
    };
}

test {
    _ = @import("tests/main.zig");
}

pub fn printTree(
    writer: *STD.Io.Writer,
    operations: []const SCHEMA.OPERATION,
    loaded_manifests: []const MANIFEST.LoadedManifest,
) !void {
    var current_platform: ?[]const u8 = null;

    for (operations) |operation| {
        if (current_platform == null or !STD.mem.eql(u8, current_platform.?, operation.platform)) {
            current_platform = operation.platform;

            var count: usize = 0;

            for (operations) |candidate| {
                if (STD.mem.eql(u8, candidate.platform, operation.platform)) count += 1;
            }

            try writer.print("{s}: {d} change(s)\n", .{ operation.platform, count });
        }

        const SYMBOL = operationSymbol(operation.operation_type);
        const CAMPAIGN = findCampaign(loaded_manifests, operation) orelse {
            try TREE.printNodeLine(writer, 0, "{s} {s}", .{ SYMBOL, operation.campaign });

            continue;
        };

        try printCampaignNode(writer, SYMBOL, CAMPAIGN);

        for (CAMPAIGN.ad_groups) |ad_group| {
            try printAdGroupNode(writer, SYMBOL, ad_group);

            for (ad_group.ads) |ad| {
                try printAdNode(writer, SYMBOL, ad);
            }
        }
    }
}

pub fn findCampaign(
    loaded_manifests: []const MANIFEST.LoadedManifest,
    operation: SCHEMA.OPERATION,
) ?MANIFEST.SCHEMA.CAMPAIGN {
    const FILE = operation.input_manifest orelse return null;

    for (loaded_manifests) |loaded_manifest| {
        if (!STD.mem.eql(u8, loaded_manifest.file_path, FILE)) continue;

        for (loaded_manifest.value.campaigns) |campaign| {
            if (STD.mem.eql(u8, campaign.name, operation.campaign))
                return campaign;
        }
    }

    return null;
}

fn operationSymbol(operation_type: SCHEMA.OPERATION_TYPE) []const u8 {
    return switch (operation_type) {
        .create => "+",
        .update => "~",
        .archive => "-",
    };
}

fn printCampaignNode(
    writer: *STD.Io.Writer,
    symbol: []const u8,
    campaign: MANIFEST.SCHEMA.CAMPAIGN,
) !void {
    if (campaign.status) |status| {
        try TREE.printNodeLine(writer, 0, "{s} {s} [{s}] {s}", .{
            symbol, campaign.name, @tagName(campaign.objective), @tagName(status),
        });
    } else {
        try TREE.printNodeLine(writer, 0, "{s} {s} [{s}]", .{
            symbol, campaign.name, @tagName(campaign.objective),
        });
    }
}

fn printAdGroupNode(
    writer: *STD.Io.Writer,
    symbol: []const u8,
    ad_group: MANIFEST.SCHEMA.AD_GROUP,
) !void {
    const NAME = if (ad_group.name.len > 0) ad_group.name[0] else "(unnamed)";

    if (ad_group.status) |status| {
        try TREE.printNodeLine(writer, 1, "{s} {s} [{s}]", .{ symbol, NAME, @tagName(status) });
    } else {
        try TREE.printNodeLine(writer, 1, "{s} {s}", .{ symbol, NAME });
    }
}

fn printAdNode(
    writer: *STD.Io.Writer,
    symbol: []const u8,
    ad: MANIFEST.SCHEMA.AD,
) !void {
    if (ad.status) |status| {
        try TREE.printNodeLine(writer, 2, "{s} {s} [{s}]", .{ symbol, ad.name, @tagName(status) });
    } else {
        try TREE.printNodeLine(writer, 2, "{s} {s}", .{ symbol, ad.name });
    }
}

pub fn fingerprint(allocator: STD.mem.Allocator, campaign: MANIFEST.SCHEMA.CAMPAIGN) ![]const u8 {
    var hasher = STD.hash.Wyhash.init(0);

    hashValue(&hasher, campaign);

    const SUM = hasher.final();

    return STD.fmt.allocPrint(allocator, "{x}", .{SUM});
}

fn hashBytes(hasher: *STD.hash.Wyhash, bytes: []const u8) void {
    hasher.update(bytes);
}

fn hashU64(hasher: *STD.hash.Wyhash, value: u64) void {
    var bytes: [8]u8 = undefined;
    STD.mem.writeInt(u64, &bytes, value, .little);
    hashBytes(hasher, &bytes);
}

fn hashValue(hasher: *STD.hash.Wyhash, value: anytype) void {
    switch (@typeInfo(@TypeOf(value))) {
        .void, .null => {},
        .bool => hashBytes(hasher, &[_]u8{@intFromBool(value)}),
        .int => |int| {
            var bytes: [@divExact(int.bits, 8)]u8 = undefined;
            STD.mem.writeInt(@TypeOf(value), &bytes, value, .little);
            hashBytes(hasher, &bytes);
        },
        .float => |float| {
            const IntT = STD.meta.Int(.unsigned, float.bits);
            var bytes: [@divExact(float.bits, 8)]u8 = undefined;
            STD.mem.writeInt(IntT, &bytes, @bitCast(value), .little);
            hashBytes(hasher, &bytes);
        },
        .enum_literal => hashBytes(hasher, value),
        .@"enum" => hashBytes(hasher, @tagName(value)),
        .optional => {
            if (value) |payload| {
                hashBytes(hasher, &.{1});
                hashValue(hasher, payload);
            } else {
                hashBytes(hasher, &.{0});
            }
        },
        .pointer => |pointer| {
            switch (pointer.size) {
                .slice => {
                    const COUNT: usize = value.len;
                    hashU64(hasher, @intCast(COUNT));
                    for (value) |element| hashValue(hasher, element);
                },
                else => hashValue(hasher, value.*),
            }
        },
        .array, .vector => {
            const COUNT: usize = value.len;
            hashU64(hasher, @intCast(COUNT));
            for (value) |element| hashValue(hasher, element);
        },
        .@"struct" => |@"struct"| {
            inline for (@"struct".fields) |field| {
                hashBytes(hasher, field.name);
                hashValue(hasher, @field(value, field.name));
            }
        },
        .@"union" => |@"union"| {
            inline for (@"union".fields) |field| {
                if (STD.meta.activeTag(value) == field.name) {
                    hashBytes(hasher, field.name);
                    if (@typeInfo(field.type) != .void)
                        hashValue(hasher, @field(value, field.name));
                    break;
                }
            }
        },
        else => @compileError("unsupported type in fingerprint"),
    }
}
