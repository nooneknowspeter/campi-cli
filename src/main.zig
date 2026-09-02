const STD = @import("std");

const CLI = @import("cli/main.zig");

pub fn main(init: STD.process.Init) u8 {
    return CLI.main(init);
}

test {
    _ = @import("cli/main.zig");
}
