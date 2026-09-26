const STD = @import("std");

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

test {
    _ = @import("meta/tests/payload.zig");
    _ = @import("meta/tests/schema.zig");
    _ = @import("tiktok/tests/schema.zig");
}
