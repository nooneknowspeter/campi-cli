const STD = @import("std");

const CONTEXT = @import("context.zig");
const FS = @import("../fs/main.zig");
const PARSER = @import("parser.zig");

pub const Entry = struct {
    key: []const u8,
    value: []const u8,
};

pub fn parse(allocator: STD.mem.Allocator, source: []const u8) ![]const Entry {
    var entries: STD.ArrayList(Entry) = .empty;
    errdefer entries.deinit(allocator);

    var lines = STD.mem.splitScalar(u8, source, '\n');
    while (lines.next()) |line| {
        const TRIMMED = STD.mem.trim(u8, line, " \t\r");
        if (TRIMMED.len == 0) continue;
        if (TRIMMED[0] == '#') continue;

        const SEPARATOR = STD.mem.indexOfScalar(u8, TRIMMED, '=') orelse continue;
        const KEY = STD.mem.trim(u8, TRIMMED[0..SEPARATOR], " \t");
        if (KEY.len == 0) continue;

        var VALUE = STD.mem.trim(u8, TRIMMED[SEPARATOR + 1 ..], " \t");
        if (VALUE.len >= 2 and VALUE[0] == '"' and VALUE[VALUE.len - 1] == '"')
            VALUE = VALUE[1 .. VALUE.len - 1];

        try entries.append(allocator, .{ .key = KEY, .value = VALUE });
    }

    return entries.toOwnedSlice(allocator);
}

/// Merge parsed entries over an existing environ. Values from the entries
/// take precedence over variables already set. Returns null on allocation
/// failure.
pub fn applyEntries(
    allocator: STD.mem.Allocator,
    environ: STD.process.Environ,
    entries: []const Entry,
) ?STD.process.Environ {
    var map = STD.process.Environ.Map.init(allocator);
    defer map.deinit();
    map.putPosixBlock(environ.block.view()) catch return null;
    for (entries) |entry|
        map.put(entry.key, entry.value) catch return null;

    const BLOCK = map.createPosixBlock(allocator, .{}) catch return null;
    return STD.process.Environ{ .block = BLOCK };
}

/// Overlay the .env file in the working directory over the process
/// environment. Values from the file take precedence over variables already
/// set in the current session. Returns null on any failure so startup never
/// hard-errors.
pub fn apply(
    allocator: STD.mem.Allocator,
    context: CONTEXT.CommandContext,
    environ: ?STD.process.Environ,
    flags: []const PARSER.ResolvedFlagState,
    dir_buffer: []u8,
) ?STD.process.Environ {
    const INITIAL = environ orelse return null;

    const DIR_PATH = FS.dirPath(context, flags, dir_buffer) catch return null;
    const WORK_DIR = FS.openWorkDir(context, DIR_PATH) catch return null;
    defer WORK_DIR.close(context.io);

    const SOURCE = WORK_DIR.readFileAllocOptions(
        context.io,
        ".env",
        allocator,
        .unlimited,
        .of(u8),
        0,
    ) catch return null;
    defer allocator.free(SOURCE);

    const ENTRIES = parse(allocator, SOURCE) catch return null;
    return applyEntries(allocator, INITIAL, ENTRIES);
}
