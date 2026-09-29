const STD = @import("std");

const DOTENV = @import("../dotenv.zig");

test "parse skips blanks and comments" {
    var arena = STD.heap.ArenaAllocator.init(STD.testing.allocator);
    defer arena.deinit();

    const ENTRIES = try DOTENV.parse(
        arena.allocator(),
        "\n# a comment\nCAMPI_META_ACCESS_TOKEN=tok\n\n",
    );
    try STD.testing.expectEqual(@as(usize, 1), ENTRIES.len);
    try STD.testing.expectEqualStrings("CAMPI_META_ACCESS_TOKEN", ENTRIES[0].key);
    try STD.testing.expectEqualStrings("tok", ENTRIES[0].value);
}

test "parse strips surrounding quotes and keeps inner equals" {
    var arena = STD.heap.ArenaAllocator.init(STD.testing.allocator);
    defer arena.deinit();

    const ENTRIES = try DOTENV.parse(
        arena.allocator(),
        "CAMPI_META_ACCESS_TOKEN=\"sk-secret\"\nCAMPI_META_PAGE_ID=a=b\n",
    );
    try STD.testing.expectEqual(@as(usize, 2), ENTRIES.len);
    try STD.testing.expectEqualStrings("sk-secret", ENTRIES[0].value);
    try STD.testing.expectEqualStrings("a=b", ENTRIES[1].value);
}

test "parse skips lines without a separator" {
    var arena = STD.heap.ArenaAllocator.init(STD.testing.allocator);
    defer arena.deinit();

    const ENTRIES = try DOTENV.parse(arena.allocator(), "NO_EQUALS_HERE\nA=\n");
    try STD.testing.expectEqual(@as(usize, 1), ENTRIES.len);
    try STD.testing.expectEqualStrings("A", ENTRIES[0].key);
    try STD.testing.expectEqualStrings("", ENTRIES[0].value);
}

test "apply overlays the .env entries over a given environ" {
    var arena = STD.heap.ArenaAllocator.init(STD.testing.allocator);
    defer arena.deinit();

    const INITIAL: STD.process.Environ = .{
        .block = .{ .slice = &[2:null]?[*:0]const u8{
            @as(?[*:0]const u8, "CAMPI_META_ACCESS_TOKEN=shell-token"),
            @as(?[*:0]const u8, "UNTOUCHED=kept"),
        } },
    };

    var source_buffer: [512]u8 = undefined;
    const SOURCE = try STD.fmt.bufPrint(
        &source_buffer,
        "CAMPI_META_ACCESS_TOKEN=file-token\nNEW_KEY=new-value\n",
        .{},
    );

    const entries = try DOTENV.parse(arena.allocator(), SOURCE);
    const MERGED = DOTENV.applyEntries(arena.allocator(), INITIAL, entries).?;

    try STD.testing.expectEqualStrings(
        "file-token",
        STD.process.Environ.getPosix(MERGED, "CAMPI_META_ACCESS_TOKEN").?,
    );
    try STD.testing.expectEqualStrings(
        "new-value",
        STD.process.Environ.getPosix(MERGED, "NEW_KEY").?,
    );
    try STD.testing.expectEqualStrings(
        "kept",
        STD.process.Environ.getPosix(MERGED, "UNTOUCHED").?,
    );
}
