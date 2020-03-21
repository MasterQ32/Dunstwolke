const builtin = @import("builtin");
const std = @import("std");
const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) !void {
    const mode = b.standardReleaseOptions();
    const exe = b.addExecutable("dunstnetz", "src/main.zig");
    // exe.setTheTarget(try std.build.Target.parse("x86_64-windows-gnu"));
    exe.setBuildMode(mode);
    exe.install();

    const _test = b.addTest("src/main.zig");

    var macstr = "XX:YY:ZZ:AA:BB:CC";

    if (b.option([]const u8, "localAddress", "provide local address")) |addr| {
        std.mem.copy(u8, macstr[0..], addr);
    } else {
        var rng = std.rand.DefaultPrng.init(std.time.milliTimestamp());
        var mac: [6]u8 = undefined;
        rng.random.bytes(mac[0..]);
        _ = try std.fmt.bufPrint(macstr[0..], "{X:0^2}:{X:0^2}:{X:0^2}:{X:0^2}:{X:0^2}:{X:0^2}", mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
    }

    const run_cmd = exe.run();

    run_cmd.addArg(macstr);

    if (b.option([]const u8, "sendTo", "sends a message to this target")) |msg| {
        run_cmd.addArg(msg);
    }

    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}