const STD = @import("std");

pub const ResolvedFlagState = struct {
    long_flag: []const u8,
    short_flag: ?u8,
    is_value_included: bool,
    value: ?[]const u8 = null,
};

pub const FlagDefinition = struct {
    long_flag: []const u8,
    short_flag: ?u8,
    is_flag_a_boolean: bool,
    description: []const u8,
};

pub const ResolutionFailure = union(enum) {
    unknown_flag: []const u8,
    invalid_value: []const u8,
};

pub const Resolution = struct {
    flags: []const ResolvedFlagState,
    failure: ?ResolutionFailure,
};

pub fn isLongFlag(argument: []const u8) bool {
    return argument.len > 2 and STD.mem.startsWith(u8, argument, "--");
}

pub fn isShortFlag(argument: []const u8) bool {
    return argument.len == 2 and argument[0] == '-' and argument[1] != '-';
}

pub fn isFlag(argument: []const u8) bool {
    return isLongFlag(argument) or isShortFlag(argument);
}

/// strip the leading `--` and any `=value` suffix so long flags match their bare name
fn flagName(argument: []const u8) []const u8 {
    const BASE = if (STD.mem.indexOfScalar(u8, argument, '=')) |equal|
        argument[0..equal]
    else
        argument;

    return if (STD.mem.startsWith(u8, BASE, "--")) BASE[2..] else BASE;
}

pub fn findFlag(
    flag_definitions: []const FlagDefinition,
    argument: []const u8,
) ?FlagDefinition {
    for (flag_definitions) |definition| {
        if (isShortFlag(argument)) {
            if (definition.short_flag) |character| {
                if (argument[1] == character) return definition;
            }

            continue;
        }

        if (isLongFlag(argument)) {
            if (STD.mem.eql(u8, definition.long_flag, flagName(argument))) return definition;
        }
    }

    return null;
}

pub fn hasFlag(flags: []const ResolvedFlagState, long_flag: []const u8) bool {
    for (flags) |resolved_flag_state| {
        if (STD.mem.eql(u8, resolved_flag_state.long_flag, long_flag)) return true;
    }

    return false;
}

/// resolve argument tokens against the flag definitions
/// parsing stops on the first failure
pub fn resolveFlags(
    allocator: STD.mem.Allocator,
    flag_definitions: []const FlagDefinition,
    args: []const []const u8,
) !Resolution {
    var flags = STD.ArrayList(ResolvedFlagState).empty;

    var index: usize = 0;

    while (index < args.len) : (index += 1) {
        const ARGUMENT = args[index];

        if (!isFlag(ARGUMENT)) continue;

        const FLAG = findFlag(flag_definitions, ARGUMENT) orelse
            return .{
                .flags = try flags.toOwnedSlice(allocator),
                .failure = .{ .unknown_flag = ARGUMENT },
            };

        const FLAG_VALUE = if (STD.mem.indexOfScalar(u8, ARGUMENT, '=')) |equal|
            ARGUMENT[equal + 1 ..]
        else
            null;

        if (FLAG.is_flag_a_boolean) {
            if (FLAG_VALUE) |value| {
                _ = value;

                return .{
                    .flags = try flags.toOwnedSlice(allocator),
                    .failure = .{
                        .invalid_value = ARGUMENT,
                    },
                };
            }

            try flags.append(allocator, .{
                .long_flag = FLAG.long_flag,
                .short_flag = FLAG.short_flag,
                .is_value_included = false,
            });

            continue;
        }

        if (FLAG_VALUE) |value| {
            if (value.len == 0 or isFlag(value)) {
                return .{
                    .flags = try flags.toOwnedSlice(allocator),
                    .failure = .{
                        .invalid_value = ARGUMENT,
                    },
                };
            }

            try flags.append(allocator, .{
                .long_flag = FLAG.long_flag,
                .short_flag = FLAG.short_flag,
                .is_value_included = true,
                .value = value,
            });
        } else {
            if (index + 1 >= args.len) {
                return .{
                    .flags = try flags.toOwnedSlice(allocator),
                    .failure = .{
                        .invalid_value = ARGUMENT,
                    },
                };
            }

            if (isFlag(args[index + 1])) {
                return .{
                    .flags = try flags.toOwnedSlice(allocator),
                    .failure = .{
                        .invalid_value = ARGUMENT,
                    },
                };
            }

            try flags.append(allocator, .{
                .long_flag = FLAG.long_flag,
                .short_flag = FLAG.short_flag,
                .is_value_included = false,
                .value = args[index + 1],
            });

            index += 1;
        }
    }

    return .{
        .flags = try flags.toOwnedSlice(allocator),
        .failure = null,
    };
}
