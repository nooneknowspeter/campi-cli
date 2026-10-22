const STD = @import("std");

const PLAN = @import("../plan/main.zig");

pub const NAMES = [_][]const u8{
    "meta",
    "x",
    "tiktok",
    "google",
    "reddit",
    "linkedin",
};

pub fn index(name: []const u8) ?usize {
    for (NAMES, 0..) |candidate, i| {
        if (STD.mem.eql(u8, candidate, name)) return i;
    }

    return null;
}

pub const WRITABLE_PLATFORMS = [_][]const u8{"meta"};

pub fn supportsWrites(platform: []const u8) bool {
    for (WRITABLE_PLATFORMS) |candidate| {
        if (STD.mem.eql(u8, candidate, platform)) return true;
    }

    return false;
}

pub fn firstPlatformWithoutWriteSupport(
    operations: []const PLAN.SCHEMA.OPERATION,
) ?[]const u8 {
    for (operations) |operation| {
        if (!supportsWrites(operation.platform)) return operation.platform;
    }

    return null;
}

test {
    _ = @import("google/tests/command.zig");
    _ = @import("google/tests/main.zig");
    _ = @import("google/tests/schema.zig");
    _ = @import("meta/tests/command.zig");
    _ = @import("meta/tests/payload.zig");
    _ = @import("meta/tests/schema.zig");
    _ = @import("tiktok/tests/schema.zig");
}

test "supportsWrites recognizes the implemented platforms" {
    try STD.testing.expect(supportsWrites("meta"));
    try STD.testing.expect(!supportsWrites("google"));
}

test "firstPlatformWithoutWriteSupport reports the first unimplemented platform" {
    const OPERATIONS = [_]PLAN.SCHEMA.OPERATION{
        .{
            .platform = "meta",
            .campaign = "Demo",
            .operation_type = .create,
            .external_id = null,
            .input_manifest = null,
            .manifest_hash = "",
        },
        .{
            .platform = "google",
            .campaign = "Demo",
            .operation_type = .create,
            .external_id = null,
            .input_manifest = null,
            .manifest_hash = "",
        },
    };

    try STD.testing.expectEqualStrings(
        "google",
        firstPlatformWithoutWriteSupport(&OPERATIONS).?,
    );
}
