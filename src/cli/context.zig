const STD = @import("std");

pub const ExitCode = enum(u8) {
    SUCCESS = 0,
    RUNTIME_FAILURE = 1,
    USAGE_FAILURE = 2,
};

pub const CommandContext = struct {
    stdin: *STD.Io.Reader,
    stdout: *STD.Io.Writer,
    stderr: *STD.Io.Writer,
};

/// runtime log gate; dispatch sets it from the --verbose flag
pub var verbose: bool = false;
