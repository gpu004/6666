const std = @import("std");
const checksum_fn = @import("../repo/src/vsr/checksum.zig").checksum;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const input = try std.fs.File.stdin().readToEndAlloc(allocator, 8 * 1024 * 1024);
    defer allocator.free(input);

    const checksum = checksum_fn(input);
    var bytes: [16]u8 = undefined;
    std.mem.writeInt(u128, &bytes, checksum, .little);
    try std.fs.File.stdout().writeAll(&bytes);
}
