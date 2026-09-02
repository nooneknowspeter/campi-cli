const STD = @import("std");

/// upper bound for the build.zig.zon read; it is only a few hundred bytes
const ZON_MAX_BYTES = 1 << 20;

pub fn build(b: *STD.Build) void {
    const ZON_SOURCE = b.build_root.handle.readFileAlloc(
        b.graph.io,
        "build.zig.zon",
        b.allocator,
        .limited(ZON_MAX_BYTES),
    ) catch "";

    const TARGET = b.standardTargetOptions(.{});
    const OPTIMIZE = b.standardOptimizeOption(.{});

    const BUILD_OPTIONS = b.addOptions();
    BUILD_OPTIONS.addOption([]const u8, "version_string", extractVersion(ZON_SOURCE));

    const MAIN_MODULE = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = TARGET,
        .optimize = OPTIMIZE,
    });
    MAIN_MODULE.addOptions("build_options", BUILD_OPTIONS);

    const EXE = b.addExecutable(.{
        .name = "campi-cli",
        .root_module = MAIN_MODULE,
    });

    b.installArtifact(EXE);

    const RUN_STEP = b.step("run", "Run the app");
    const RUN_CMD = b.addRunArtifact(EXE);
    RUN_STEP.dependOn(&RUN_CMD.step);
    RUN_CMD.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        RUN_CMD.addArgs(args);
    }

    const EXE_TESTS = b.addTest(.{
        .name = "campi-cli_tests",
        .root_module = MAIN_MODULE,
    });
    const RUN_EXE_TESTS = b.addRunArtifact(EXE_TESTS);
    const TEST_STEP = b.step("test", "Run tests");
    TEST_STEP.dependOn(&RUN_EXE_TESTS.step);
}

/// read the `.version = "x.y.z"` value from build.zig.zon so the CLI can print it
fn extractVersion(zon_source: []const u8) []const u8 {
    if (STD.mem.indexOf(u8, zon_source, ".version")) |start| {
        if (STD.mem.indexOfScalarPos(u8, zon_source, start, '=')) |equal| {
            var version_start = equal + 1;

            while (version_start < zon_source.len and
                (zon_source[version_start] == ' ' or zon_source[version_start] == '\t'))
            {
                version_start += 1;
            }

            if (version_start < zon_source.len and zon_source[version_start] == '"') {
                version_start += 1;

                if (STD.mem.indexOfScalarPos(u8, zon_source, version_start, '"')) |closing| {
                    return zon_source[version_start..closing];
                }
            }
        }
    }

    return "dev";
}
