const STD = @import("std");

const GOOGLE = @import("../main.zig");

test "formEncode percent-encodes reserved characters" {
    const encoded = try GOOGLE.formEncode(
        STD.testing.allocator,
        "a b+c/d&e=f~",
    );
    defer STD.testing.allocator.free(encoded);

    try STD.testing.expectEqualStrings("a%20b%2Bc%2Fd%26e%3Df~", encoded);
}

test "normalizeCustomerId strips hyphens" {
    const normalized = try GOOGLE.normalizeCustomerId(
        STD.testing.allocator,
        "123-456-7890",
    );
    defer STD.testing.allocator.free(normalized);

    try STD.testing.expectEqualStrings("1234567890", normalized);
}
