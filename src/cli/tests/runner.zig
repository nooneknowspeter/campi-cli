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

    const ARGS = [_][]const u8{ "campi-cli", "platform", "meta" };
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

    const ARGS = [_][]const u8{ "campi-cli", "platform", "tiktok" };
    const EXIT_CODE = CLI.dispatchCommand(arena.allocator(), COMMAND_CONTEXT, &ARGS);

    var stderr_output = stderr_writer.toArrayList();
    defer stderr_output.deinit(STD.testing.allocator);

    try STD.testing.expectEqual(CONTEXT.ExitCode.RUNTIME_FAILURE, EXIT_CODE);
    try STD.testing.expect(
        STD.mem.indexOf(u8, stderr_output.items, "could not read the environment") != null,
    );
}

test "platform without a subcommand fails with usage" {
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

    const ARGS = [_][]const u8{ "campi-cli", "platform" };
    const EXIT_CODE = CLI.dispatchCommand(arena.allocator(), COMMAND_CONTEXT, &ARGS);

    var stderr_output = stderr_writer.toArrayList();
    defer stderr_output.deinit(STD.testing.allocator);

    try STD.testing.expectEqual(CONTEXT.ExitCode.USAGE_FAILURE, EXIT_CODE);
    try STD.testing.expect(
        STD.mem.indexOf(u8, stderr_output.items, "usage: campi-cli platform <name> [ARGS]") != null,
    );
}

test "an unknown platform fails with usage" {
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

    const ARGS = [_][]const u8{ "campi-cli", "platform", "nope" };
    const EXIT_CODE = CLI.dispatchCommand(arena.allocator(), COMMAND_CONTEXT, &ARGS);

    var stderr_output = stderr_writer.toArrayList();
    defer stderr_output.deinit(STD.testing.allocator);

    try STD.testing.expectEqual(CONTEXT.ExitCode.USAGE_FAILURE, EXIT_CODE);
    try STD.testing.expect(
        STD.mem.indexOf(u8, stderr_output.items, "unknown platform: nope") != null,
    );
}

test "destroy without any recorded state reports no changes" {
    var arena = STD.heap.ArenaAllocator.init(STD.testing.allocator);
    defer arena.deinit();

    var tmp = STD.testing.tmpDir(.{});
    defer tmp.cleanup();

    var cwd_buffer: [STD.Io.Dir.max_path_bytes]u8 = undefined;
    const CWD_LEN = try STD.process.currentPath(STD.testing.io, &cwd_buffer);
    const CWD = cwd_buffer[0..CWD_LEN];
    const WORK_DIR_PATH = try STD.fs.path.join(arena.allocator(), &.{ CWD, ".zig-cache", "tmp", tmp.sub_path[0..] });

    var work_dir = try STD.Io.Dir.openDirAbsolute(STD.testing.io, WORK_DIR_PATH, .{});
    defer work_dir.close(STD.testing.io);

    try work_dir.writeFile(STD.testing.io, .{
        .sub_path = "config.campi",
        .data =
        \\.{
        \\    .campi_version = "0.0.0",
        \\    .config_version = "0.1.0",
        \\    .project_name = "demo",
        \\    .state_file_location_type = .local,
        \\    .state_file_uri = "state.campi",
        \\    .platform_configs = .{
        \\        .meta = null,
        \\        .x = null,
        \\        .tiktok = null,
        \\        .google = null,
        \\        .reddit = null,
        \\        .linkedin = null,
        \\    },
        \\    .manifest_files = .{ .manifest_files = .{"demo.manifest.campi"} },
        \\}
        \\
        ,
        .flags = .{},
    });

    var stdin_reader = STD.Io.Reader.fixed(&.{});
    var stdout_writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);
    var stderr_writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);

    const COMMAND_CONTEXT = CONTEXT.CommandContext{
        .stdin = &stdin_reader,
        .stdout = &stdout_writer.writer,
        .stderr = &stderr_writer.writer,
        .io = STD.testing.io,
        .positionals = &.{ "destroy", "-d", WORK_DIR_PATH },
    };

    const ARGS = [_][]const u8{ "campi-cli", "destroy", "-d", WORK_DIR_PATH };
    const EXIT_CODE = CLI.dispatchCommand(arena.allocator(), COMMAND_CONTEXT, &ARGS);

    var stdout_output = stdout_writer.toArrayList();
    defer stdout_output.deinit(STD.testing.allocator);

    try STD.testing.expectEqual(CONTEXT.ExitCode.SUCCESS, EXIT_CODE);
    try STD.testing.expect(
        STD.mem.indexOf(u8, stdout_output.items, "no changes") != null,
    );
}

test "destroy dry run reports the campaigns it would archive" {
    var arena = STD.heap.ArenaAllocator.init(STD.testing.allocator);
    defer arena.deinit();

    var tmp = STD.testing.tmpDir(.{});
    defer tmp.cleanup();

    var cwd_buffer: [STD.Io.Dir.max_path_bytes]u8 = undefined;
    const CWD_LEN = try STD.process.currentPath(STD.testing.io, &cwd_buffer);
    const CWD = cwd_buffer[0..CWD_LEN];
    const WORK_DIR_PATH = try STD.fs.path.join(arena.allocator(), &.{ CWD, ".zig-cache", "tmp", tmp.sub_path[0..] });

    var work_dir = try STD.Io.Dir.openDirAbsolute(STD.testing.io, WORK_DIR_PATH, .{});
    defer work_dir.close(STD.testing.io);

    try work_dir.writeFile(STD.testing.io, .{
        .sub_path = "config.campi",
        .data =
        \\.{
        \\    .campi_version = "0.0.0",
        \\    .config_version = "0.1.0",
        \\    .project_name = "demo",
        \\    .state_file_location_type = .local,
        \\    .state_file_uri = "state.campi",
        \\    .platform_configs = .{
        \\        .meta = null,
        \\        .x = null,
        \\        .tiktok = null,
        \\        .google = null,
        \\        .reddit = null,
        \\        .linkedin = null,
        \\    },
        \\    .manifest_files = .{ .manifest_files = .{"demo.manifest.campi"} },
        \\}
        \\
        ,
        .flags = .{},
    });

    try work_dir.writeFile(STD.testing.io, .{
        .sub_path = "state.campi",
        .data =
        \\.{
        \\    .state_version = "0.0.0",
        \\    .applied_at = "2026-10-10T00:00:00Z",
        \\    .manifest_files = .{"demo.manifest.campi"},
        \\    .platforms = .{
        \\        .meta = .{
        \\            .{
        \\                .campaign = "Demo campaign",
        \\                .external_id = "1234567890",
        \\                .input_manifest = "demo.manifest.campi",
        \\                .manifest_hash = "abc123",
        \\            },
        \\        },
        \\        .x = null,
        \\        .tiktok = null,
        \\        .google = null,
        \\        .reddit = null,
        \\        .linkedin = null,
        \\    },
        \\}
        \\
        ,
        .flags = .{},
    });

    var stdin_reader = STD.Io.Reader.fixed(&.{});
    var stdout_writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);
    var stderr_writer = STD.Io.Writer.Allocating.init(STD.testing.allocator);

    const COMMAND_CONTEXT = CONTEXT.CommandContext{
        .stdin = &stdin_reader,
        .stdout = &stdout_writer.writer,
        .stderr = &stderr_writer.writer,
        .io = STD.testing.io,
        .positionals = &.{ "destroy", "-d", WORK_DIR_PATH },
    };

    const ARGS = [_][]const u8{ "campi-cli", "destroy", "-d", WORK_DIR_PATH };
    const EXIT_CODE = CLI.dispatchCommand(arena.allocator(), COMMAND_CONTEXT, &ARGS);

    var stdout_output = stdout_writer.toArrayList();
    defer stdout_output.deinit(STD.testing.allocator);

    try STD.testing.expectEqual(CONTEXT.ExitCode.PENDING_UPDATES, EXIT_CODE);
    try STD.testing.expect(
        STD.mem.indexOf(u8, stdout_output.items, "archive Demo campaign") != null,
    );
    try STD.testing.expect(
        STD.mem.indexOf(u8, stdout_output.items, "dry run: would destroy 1 campaign(s)") != null,
    );
}

test "help destroy prints the destroy help" {
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

    const ARGS = [_][]const u8{ "campi-cli", "help", "destroy" };
    const EXIT_CODE = CLI.dispatchCommand(arena.allocator(), COMMAND_CONTEXT, &ARGS);

    var stdout_output = stdout_writer.toArrayList();
    defer stdout_output.deinit(STD.testing.allocator);

    try STD.testing.expectEqual(CONTEXT.ExitCode.SUCCESS, EXIT_CODE);
    try STD.testing.expect(
        STD.mem.indexOf(u8, stdout_output.items, "campi-cli destroy [ARGS]") != null,
    );
}
