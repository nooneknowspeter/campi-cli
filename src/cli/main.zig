const STD = @import("std");

const COMMANDS = @import("commands.zig");
const CONTEXT = @import("context.zig");
const PARSER = @import("parser.zig");

pub const ExitCode = CONTEXT.ExitCode;
pub const CommandContext = CONTEXT.CommandContext;

pub fn dispatchCommand(
    allocator: STD.mem.Allocator,
    context: CommandContext,
    args: []const []const u8,
) ExitCode {
    if (args.len <= 1) {
        context.stdout.print("{s}", .{COMMANDS.HELP.MAIN}) catch
            return ExitCode.RUNTIME_FAILURE;

        return ExitCode.SUCCESS;
    }

    if (STD.mem.eql(u8, args[1], "-h") or STD.mem.eql(u8, args[1], "--help")) {
        context.stdout.print("{s}", .{COMMANDS.HELP.MAIN}) catch
            return ExitCode.RUNTIME_FAILURE;

        return ExitCode.SUCCESS;
    }

    if (STD.mem.eql(u8, args[1], "help")) {
        if (args.len >= 3) {
            if (PARSER.isFlag(args[2])) {
                context.stdout.print("{s}", .{COMMANDS.HELP.HELP}) catch
                    return ExitCode.RUNTIME_FAILURE;

                return ExitCode.SUCCESS;
            }

            const TARGET = COMMANDS.findCommand(args[2]) orelse {
                context.stderr.print(
                    "unknown command: {s}\n",
                    .{args[2]},
                ) catch return ExitCode.RUNTIME_FAILURE;

                return ExitCode.USAGE_FAILURE;
            };

            context.stdout.print("{s}", .{TARGET.help}) catch
                return ExitCode.RUNTIME_FAILURE;

            return ExitCode.SUCCESS;
        }

        context.stdout.print("{s}", .{COMMANDS.HELP.MAIN}) catch
            return ExitCode.RUNTIME_FAILURE;

        return ExitCode.SUCCESS;
    }

    const COMMAND = COMMANDS.findCommand(args[1]) orelse {
        context.stderr.print("unknown command: {s}\n", .{args[1]}) catch {
            return ExitCode.RUNTIME_FAILURE;
        };

        return ExitCode.USAGE_FAILURE;
    };

    const RESOLVED_FLAGS = PARSER.resolveFlags(allocator, COMMAND.flags, args[2..]) catch
        return ExitCode.RUNTIME_FAILURE;

    if (RESOLVED_FLAGS.failure) |failure| {
        switch (failure) {
            .unknown_flag => |argument| {
                context.stderr.print("unknown flag: {s}\n", .{argument}) catch
                    return ExitCode.RUNTIME_FAILURE;
            },
            .invalid_value => |argument| {
                context.stderr.print("invalid value for flag: {s}\n", .{argument}) catch
                    return ExitCode.RUNTIME_FAILURE;
            },
        }

        return ExitCode.USAGE_FAILURE;
    }

    if (PARSER.hasFlag(RESOLVED_FLAGS.flags, "help")) {
        context.stdout.print("{s}", .{COMMAND.help}) catch
            return ExitCode.RUNTIME_FAILURE;

        return ExitCode.SUCCESS;
    }

    // toggle verbosity
    CONTEXT.verbose = PARSER.hasFlag(RESOLVED_FLAGS.flags, "verbose");

    STD.log.debug("dispatching command: {s}", .{COMMAND.name});

    STD.log.debug("resolved {d} flags", .{RESOLVED_FLAGS.flags.len});

    var command_context = context;
    command_context.positionals = RESOLVED_FLAGS.positionals;

    return COMMAND.run(allocator, command_context, RESOLVED_FLAGS.flags);
}

pub fn main(init: STD.process.Init) u8 {
    const IO = init.io;
    const ALLOCATOR = init.arena.allocator();

    var stdin_buffer: [1024]u8 = undefined;
    var stdin_reader = STD.Io.File.stdin().reader(IO, &stdin_buffer);

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = STD.Io.File.stdout().writer(IO, &stdout_buffer);

    var stderr_buffer: [1024]u8 = undefined;
    var stderr_writer = STD.Io.File.stderr().writer(IO, &stderr_buffer);

    const COMMAND_CONTEXT = CommandContext{
        .io = init.io,
        .stdin = &stdin_reader.interface,
        .stdout = &stdout_writer.interface,
        .stderr = &stderr_writer.interface,
        .environ = init.minimal.environ,
    };

    const ARGS = init.minimal.args.toSlice(ALLOCATOR) catch |err| {
        STD.log.err("{any}", .{err});

        return @intFromEnum(ExitCode.RUNTIME_FAILURE);
    };

    const EXIT_CODE = dispatchCommand(ALLOCATOR, COMMAND_CONTEXT, ARGS);

    stdout_writer.flush() catch return @intFromEnum(ExitCode.RUNTIME_FAILURE);
    stderr_writer.flush() catch return @intFromEnum(ExitCode.RUNTIME_FAILURE);

    return @intFromEnum(EXIT_CODE);
}

test {
    _ = @import("tests/parser.zig");
    _ = @import("tests/runner.zig");
    _ = @import("tests/env.zig");
}
