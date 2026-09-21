const STD = @import("std");

const CONTEXT = @import("../context.zig");
const CLI = @import("../main.zig");

test "check if no arguments prints the main help" {
    var arena = STD.heap.ArenaAllocator.init(STD.testing.allocator);
    defer arena.deinit();

    var stdin_reader = STD.Io.Reader.fixed(&.{});
    var stdout_writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);
    var stderr_writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);

    const COMMAND_CONTEXT = CONTEXT.CommandContext{
        .stdin = &stdin_reader,
        .stdout = &stdout_writer.writer,
        .stderr = &stderr_writer.writer,
        .io = STD.testing.io,
    };

    const ARGS = [_][]const u8{"campi-cli"};
    const EXIT_CODE = CLI.dispatchCommand(arena.allocator(), COMMAND_CONTEXT, &ARGS);

    var stdout_output = stdout_writer.toArrayList();
    defer stdout_output.deinit(STD.testing.allocator);

    try STD.testing.expectEqual(CONTEXT.ExitCode.SUCCESS, EXIT_CODE);
    try STD.testing.expect(
        STD.mem.indexOf(u8, stdout_output.items, "campi-cli <COMMAND> [ARGS]") != null,
    );
}

test "check if the help flag prints the main help" {
    var arena = STD.heap.ArenaAllocator.init(STD.testing.allocator);
    defer arena.deinit();

    var stdin_reader = STD.Io.Reader.fixed(&.{});
    var stdout_writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);
    var stderr_writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);

    const COMMAND_CONTEXT = CONTEXT.CommandContext{
        .stdin = &stdin_reader,
        .stdout = &stdout_writer.writer,
        .stderr = &stderr_writer.writer,
        .io = STD.testing.io,
    };

    const ARGS = [_][]const u8{ "campi-cli", "-h" };
    const EXIT_CODE = CLI.dispatchCommand(arena.allocator(), COMMAND_CONTEXT, &ARGS);

    var stdout_output = stdout_writer.toArrayList();
    defer stdout_output.deinit(STD.testing.allocator);

    try STD.testing.expectEqual(CONTEXT.ExitCode.SUCCESS, EXIT_CODE);
    try STD.testing.expect(
        STD.mem.indexOf(u8, stdout_output.items, "campi-cli <COMMAND> [ARGS]") != null,
    );
}

test "check if version prints the version string" {
    var arena = STD.heap.ArenaAllocator.init(STD.testing.allocator);
    defer arena.deinit();

    var stdin_reader = STD.Io.Reader.fixed(&.{});
    var stdout_writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);
    var stderr_writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);

    const COMMAND_CONTEXT = CONTEXT.CommandContext{
        .stdin = &stdin_reader,
        .stdout = &stdout_writer.writer,
        .stderr = &stderr_writer.writer,
        .io = STD.testing.io,
    };

    const ARGS = [_][]const u8{ "campi-cli", "version" };
    const EXIT_CODE = CLI.dispatchCommand(arena.allocator(), COMMAND_CONTEXT, &ARGS);

    var stdout_output = stdout_writer.toArrayList();
    defer stdout_output.deinit(STD.testing.allocator);

    try STD.testing.expectEqual(CONTEXT.ExitCode.SUCCESS, EXIT_CODE);
    try STD.testing.expectEqualStrings("0.0.0\n", stdout_output.items);
}

test "check if the help flag on a command prints the command help" {
    var arena = STD.heap.ArenaAllocator.init(STD.testing.allocator);
    defer arena.deinit();

    var stdin_reader = STD.Io.Reader.fixed(&.{});
    var stdout_writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);
    var stderr_writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);

    const COMMAND_CONTEXT = CONTEXT.CommandContext{
        .stdin = &stdin_reader,
        .stdout = &stdout_writer.writer,
        .stderr = &stderr_writer.writer,
        .io = STD.testing.io,
    };

    const ARGS = [_][]const u8{ "campi-cli", "plan", "--help" };
    const EXIT_CODE = CLI.dispatchCommand(arena.allocator(), COMMAND_CONTEXT, &ARGS);

    var stdout_output = stdout_writer.toArrayList();
    defer stdout_output.deinit(STD.testing.allocator);

    try STD.testing.expectEqual(CONTEXT.ExitCode.SUCCESS, EXIT_CODE);
    try STD.testing.expect(
        STD.mem.indexOf(u8, stdout_output.items, "--export") != null,
    );
}

test "check if help with a command prints the command help" {
    var arena = STD.heap.ArenaAllocator.init(STD.testing.allocator);
    defer arena.deinit();

    var stdin_reader = STD.Io.Reader.fixed(&.{});
    var stdout_writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);
    var stderr_writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);

    const COMMAND_CONTEXT = CONTEXT.CommandContext{
        .stdin = &stdin_reader,
        .stdout = &stdout_writer.writer,
        .stderr = &stderr_writer.writer,
        .io = STD.testing.io,
    };

    const ARGS = [_][]const u8{ "campi-cli", "help", "version" };
    const EXIT_CODE = CLI.dispatchCommand(arena.allocator(), COMMAND_CONTEXT, &ARGS);

    var stdout_output = stdout_writer.toArrayList();
    defer stdout_output.deinit(STD.testing.allocator);

    try STD.testing.expectEqual(CONTEXT.ExitCode.SUCCESS, EXIT_CODE);
    try STD.testing.expect(
        STD.mem.indexOf(u8, stdout_output.items, "Display the tool version") != null,
    );
}

test "ensure an unknown command fails with usage failure" {
    var arena = STD.heap.ArenaAllocator.init(STD.testing.allocator);
    defer arena.deinit();

    var stdin_reader = STD.Io.Reader.fixed(&.{});
    var stdout_writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);
    var stderr_writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);

    const COMMAND_CONTEXT = CONTEXT.CommandContext{
        .stdin = &stdin_reader,
        .stdout = &stdout_writer.writer,
        .stderr = &stderr_writer.writer,
        .io = STD.testing.io,
    };

    const ARGS = [_][]const u8{ "campi-cli", "foo" };
    const EXIT_CODE = CLI.dispatchCommand(arena.allocator(), COMMAND_CONTEXT, &ARGS);

    var stderr_output = stderr_writer.toArrayList();
    defer stderr_output.deinit(STD.testing.allocator);

    try STD.testing.expectEqual(CONTEXT.ExitCode.USAGE_FAILURE, EXIT_CODE);
    try STD.testing.expect(
        STD.mem.indexOf(u8, stderr_output.items, "unknown command: foo") != null,
    );
}

test "ensure an unconfigured meta command fails at runtime" {
    var arena = STD.heap.ArenaAllocator.init(STD.testing.allocator);
    defer arena.deinit();

    var stdin_reader = STD.Io.Reader.fixed(&.{});
    var stdout_writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);
    var stderr_writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);

    const COMMAND_CONTEXT = CONTEXT.CommandContext{
        .stdin = &stdin_reader,
        .stdout = &stdout_writer.writer,
        .stderr = &stderr_writer.writer,
        .io = STD.testing.io,
    };

    const ARGS = [_][]const u8{ "campi-cli", "meta" };
    const EXIT_CODE = CLI.dispatchCommand(arena.allocator(), COMMAND_CONTEXT, &ARGS);

    var stderr_output = stderr_writer.toArrayList();
    defer stderr_output.deinit(STD.testing.allocator);

    try STD.testing.expectEqual(CONTEXT.ExitCode.RUNTIME_FAILURE, EXIT_CODE);
    try STD.testing.expect(
        STD.mem.indexOf(u8, stderr_output.items, "could not read the environment") != null,
    );
}

test "ensure an unconfigured tiktok command fails at runtime" {
    var arena = STD.heap.ArenaAllocator.init(STD.testing.allocator);
    defer arena.deinit();

    var stdin_reader = STD.Io.Reader.fixed(&.{});
    var stdout_writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);
    var stderr_writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);

    const COMMAND_CONTEXT = CONTEXT.CommandContext{
        .stdin = &stdin_reader,
        .stdout = &stdout_writer.writer,
        .stderr = &stderr_writer.writer,
        .io = STD.testing.io,
    };

    const ARGS = [_][]const u8{ "campi-cli", "tiktok" };
    const EXIT_CODE = CLI.dispatchCommand(arena.allocator(), COMMAND_CONTEXT, &ARGS);

    var stderr_output = stderr_writer.toArrayList();
    defer stderr_output.deinit(STD.testing.allocator);

    try STD.testing.expectEqual(CONTEXT.ExitCode.RUNTIME_FAILURE, EXIT_CODE);
    try STD.testing.expect(
        STD.mem.indexOf(u8, stderr_output.items, "could not read the environment") != null,
    );
}
