const STD = @import("std");

pub fn build(b: *STD.Build) void {
    const TARGET = b.standardTargetOptions(.{});
    const OPTIMIZE = b.standardOptimizeOption(.{});

    const MAIN_MODULE =
        b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = TARGET,
            .optimize = OPTIMIZE,
        });

    const EXE = b.addExecutable(.{
        .name = "campi_cli",
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

    // const MOD_TESTS = b.addTest(.{
    //     .root_module = MODULE,
    // });
    // const RUN_MOD_TESTS = b.addRunArtifact(MOD_TESTS);
    const EXE_TESTS = b.addTest(.{
        .root_module = EXE.root_module,
    });
    const RUN_EXE_TESTS = b.addRunArtifact(EXE_TESTS);
    const TEST_STEP = b.step("test", "Run tests");
    // TEST_STEP.dependOn(&RUN_MOD_TESTS.step);
    TEST_STEP.dependOn(&RUN_EXE_TESTS.step);
}
