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
