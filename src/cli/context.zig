const STD = @import("std");

pub const ExitCode = enum(u8) {
    SUCCESS = 0,
    RUNTIME_FAILURE = 1,
    USAGE_FAILURE = 2,
    PENDING_UPDATES = 3,
};

pub const Message = struct {
    pub const COULD_NOT_DETERMINE_WORKING_DIRECTORY = "could not determine the working directory";
    pub const WORKING_DIRECTORY_DOES_NOT_EXIST = "working directory does not exist: ";
    pub const CONFIG_NOT_FOUND = "could not find config.campi.zon; run campi-cli init";
    pub const CONFIG_COULD_NOT_BE_LOADED = "could not load config: ";
    pub const CONFIG_COULD_NOT_BE_WRITTEN = "could not write config: ";
    pub const NO_MANIFEST_FILES_CONFIGURED = "no manifest files configured";
    pub const MANIFEST_REGEX_NOT_IMPLEMENTED = "manifest selection by regex is not implemented yet: ";
    pub const VALID_MANIFEST = "valid manifest: ";
    pub const INVALID_MANIFEST = "invalid manifest: ";
    pub const MANIFEST_COULD_NOT_BE_WRITTEN = "could not write manifest: ";
    pub const FMT_LSP_NOT_IMPLEMENTED = "not implemented yet";
    pub const STATE_BACKEND_NOT_IMPLEMENTED = "state backend is not implemented yet: ";
    pub const VALID_STATE = "found state file: ";
    pub const INVALID_STATE = "invalid state file: ";
    pub const STATE_LOCK_FAILED = "could not probe state lock: ";
};

pub const CommandContext = struct {
    stdin: *STD.Io.Reader,
    stdout: *STD.Io.Writer,
    stderr: *STD.Io.Writer,
    io: STD.Io,
};

/// runtime log gate; dispatch sets it from the --verbose flag
pub var verbose: bool = false;
