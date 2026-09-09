const STD = @import("std");

const CONFIG = @import("../config/main.zig");
const CONTEXT = @import("../cli/context.zig");

pub const SCHEMA = @import("schema.zig");

pub const LOCK_FILENAME = "state.campi.lock";

pub const LoadedState = struct {
    file_path: []const u8,
    source: []const u8,
    value: SCHEMA.STATE,
};

pub const LoadState = union(enum) {
    loaded: LoadedState,
    missing,
    invalid,
};

pub const LockState = enum {
    available,
    held,
    failed,
};

pub const StateLocation = union(enum) {
    local: []const u8,
    cloud: []const u8,
};

pub fn resolveStateLocation(
    context: CONTEXT.CommandContext,
    config: CONFIG.SCHEMA.CONFIG,
) ?StateLocation {
    switch (config.state_file_location_type) {
        .local => return .{ .local = config.state_file_uri },
        .cloud => {
            context.stderr.print(
                \\{s}{s}
                \\
            , .{ CONTEXT.Message.STATE_BACKEND_NOT_IMPLEMENTED, config.state_file_uri }) catch
                return null;

            return null;
        },
    }
}

pub fn load(
    allocator: STD.mem.Allocator,
    context: CONTEXT.CommandContext,
    work_dir: STD.Io.Dir,
    file_name: []const u8,
) LoadState {
    const SOURCE = work_dir.readFileAllocOptions(
        context.io,
        file_name,
        allocator,
        .unlimited,
        .of(u8),
        0,
    ) catch |err| {
        switch (err) {
            error.FileNotFound => return .missing,
            else => |unexpected| {
                context.stderr.print(
                    \\{s}{s}
                    \\
                    \\{any}
                    \\
                , .{ CONTEXT.Message.INVALID_STATE, file_name, unexpected }) catch
                    return .invalid;

                return .invalid;
            },
        }
    };

    const VALUE = STD.zon.parse.fromSliceAlloc(SCHEMA.STATE, allocator, SOURCE, null, .{}) catch |err| {
        context.stderr.print(
            \\{s}{s}
            \\
            \\{any}
            \\
        , .{ CONTEXT.Message.INVALID_STATE, file_name, err }) catch
            return .invalid;

        return .invalid;
    };

    context.stdout.print(
        \\{s}{s}
        \\
    , .{ CONTEXT.Message.VALID_STATE, file_name }) catch
        return .invalid;

    return .{
        .loaded = .{
            .file_path = file_name,
            .source = SOURCE,
            .value = VALUE,
        },
    };
}

pub fn acquireLock(context: CONTEXT.CommandContext, work_dir: STD.Io.Dir) LockState {
    var lock_file = work_dir.openFile(context.io, LOCK_FILENAME, .{
        .mode = .read_only,
        .lock = .exclusive,
        .lock_nonblocking = true,
    }) catch |err| {
        switch (err) {
            error.FileNotFound => return .available,
            error.WouldBlock => return .held,
            else => |unexpected| {
                context.stderr.print(
                    \\{s}{any}
                    \\
                , .{ CONTEXT.Message.STATE_LOCK_FAILED, unexpected }) catch
                    return .failed;

                return .failed;
            },
        }
    };
    lock_file.close(context.io);

    return .available;
}
