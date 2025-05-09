const std = @import("std");
const typedFsm = @import("typed_fsm");
const atm_gui = @import("atm-gui.zig");

pub fn main() !void {
    var gpa_instance = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = gpa_instance.allocator();

    var prng = std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        std.posix.getrandom(std.mem.asBytes(&seed)) catch unreachable;
        break :blk seed;
    });
    const rand = prng.random();

    const rand_val = rand.int(u32);

    var nlist = typedFsm.NodeList.init(gpa);
    defer nlist.deinit();
    var elist = typedFsm.EdgeList.init(gpa);
    defer elist.deinit();

    const dot_path = try std.fmt.allocPrint(gpa, ".graph/{d}.dot", .{rand_val});
    const png_path = try std.fmt.allocPrint(gpa, ".graph/{d}.png", .{rand_val});

    try typedFsm.graph(atm_gui.AtmSt, &nlist, &elist, dot_path);

    const cmd = [_][]const u8{ "dot", "-Tpng", dot_path, "-o", png_path };
    var cp = std.process.Child.init(&cmd, gpa);
    try cp.spawn();
    _ = try cp.wait();

    var dir = std.fs.cwd();
    try dir.deleteFile(dot_path);

    const cmd1 = [_][]const u8{ "eog", png_path };
    var cp1 = std.process.Child.init(&cmd1, gpa);
    try cp1.spawn();
    _ = try cp1.wait();
}
