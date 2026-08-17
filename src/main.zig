const STD = @import("std");

const HELP = @import("help/main.zig");
const CONFIG = @import("config/main.zig");

pub fn main(init: STD.process.Init) !void {
    const IO = init.io;
    const ARENA_ALLOCTOR: STD.mem.Allocator = init.arena.allocator();
    const ARGS = init.minimal.args.toSlice(ARENA_ALLOCTOR) catch |err| {
        STD.log.err("{any}", .{err});

        return err;
    };

    const STDIN_FD = STD.Io.File.stdin();
    var stdin_buffer: [1024]u8 = undefined;
    var stdin_writer = STDIN_FD.writer(IO, &stdin_buffer);
    const STDIN = &stdin_writer.interface;
    _ = STDIN;

    const STDOUT_FD = STD.Io.File.stdout();
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = STDOUT_FD.writer(IO, &stdout_buffer);
    const STDOUT = &stdout_writer.interface;

    const STDERR_FD = STD.Io.File.stdout();
    var stderr_buffer: [1024]u8 = undefined;
    var stderr_writer = STDERR_FD.writer(IO, &stderr_buffer);
    const STDERR = &stderr_writer.interface;
    _ = STDERR;

    if (ARGS.len <= 1 or ARGS.len == 2) {
        try STDOUT.print("{s}", .{HELP.MAIN});
        try STDOUT.flush();
        return;
    }

    if (ARGS.len > 1) {
        if (STD.mem.eql(u8, ARGS[1], "-h")) {
            try STDOUT.print("{s}", .{HELP.MAIN});
            try STDOUT.flush();
            return;
        }
    }
}
