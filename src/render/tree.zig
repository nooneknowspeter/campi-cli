const STD = @import("std");

pub fn printDepth(writer: *STD.Io.Writer, depth: usize) !void {
    for (0..depth) |_| try writer.writeAll("|  ");
}

pub fn printNodeLine(
    writer: *STD.Io.Writer,
    depth: usize,
    comptime format: []const u8,
    args: anytype,
) !void {
    try printDepth(writer, depth);
    try writer.writeAll("|- ");
    try writer.print(format, args);
    try writer.writeAll("\n");
}

pub fn printEmptyLine(
    writer: *STD.Io.Writer,
    depth: usize,
) !void {
    try printDepth(writer, depth);
    try writer.writeAll("- none found\n");
}

test "printNodeLine indents each depth with a pipe" {
    var writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);

    try printNodeLine(&writer.writer, 0, "{s}", .{"root"});
    try printNodeLine(&writer.writer, 1, "{s} {d}", .{ "child", 2 });
    try printEmptyLine(&writer.writer, 2);

    var output = writer.toArrayList();
    defer output.deinit(STD.testing.allocator);

    try STD.testing.expectEqualStrings(
        \\|- root
        \\|  |- child 2
        \\|  |  - none found
        \\
    , output.items);
}
