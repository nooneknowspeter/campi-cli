const STD = @import("std");

pub const ExitCode = enum(u8) {
    SUCCESS = 0,
    RUNTIME_FAILURE = 1,
    USAGE_FAILURE = 2,
    PENDING_UPDATES = 3,
};

pub const Message = struct {
    pub const NOT_IMPLEMENTED = "not yet implemented";
    pub const COULD_NOT_DETERMINE_WORKING_DIRECTORY = "could not determine the working directory";
    pub const WORKING_DIRECTORY_DOES_NOT_EXIST = "working directory does not exist: ";
    pub const CONFIG_NOT_FOUND = "could not find config.campi; run the init command";
    pub const CONFIG_COULD_NOT_BE_LOADED = "could not load config: ";
    pub const CONFIG_COULD_NOT_BE_WRITTEN = "could not write config: ";
    pub const NO_MANIFEST_FILES_CONFIGURED = "no manifest files configured";
    pub const VALID_MANIFEST = "valid manifest: ";
    pub const INVALID_MANIFEST = "invalid manifest: ";
    pub const MANIFEST_COULD_NOT_BE_WRITTEN = "could not write manifest: ";
    pub const VALID_STATE = "found state file: ";
    pub const INVALID_STATE = "invalid state file: ";
    pub const STATE_LOCK_FAILED = "could not probe state lock: ";
    pub const STATE_LOCK_COULD_NOT_BE_TAKEN = "could not take state lock: ";
    pub const STATE_LOCK_HELD = "state file is locked by another process";
    pub const NO_CHANGES = "no changes";
    pub const PLAN_NOT_COMPUTED = "could not compute plan";
    pub const STATE_COULD_NOT_BE_WRITTEN = "could not write state: ";
    pub const IMPORT_USAGE = "campi-cli import <platform> <campaign> <external-id>";
    pub const IMPORT_UNKNOWN_PLATFORM = "unknown platform: ";
    pub const IMPORT_ALREADY_IMPORTED = "campaign is already imported on this platform: ";
};

pub const CommandContext = struct {
    io: STD.Io,
    stdin: *STD.Io.Reader,
    stdout: *STD.Io.Writer,
    stderr: *STD.Io.Writer,
    positionals: []const []const u8 = &.{},
    environ: ?STD.process.Environ = null,
};

/// runtime log gate; dispatch sets it from the --verbose flag
pub var verbose: bool = false;
