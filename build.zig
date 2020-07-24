const std = @import("std");
const Builder = std.build.Builder;

const pkgs = struct {
    const network = std.build.Pkg{
        .name = "network",
        .path = "./lib/zig-network/network.zig",
    };

    const sdl2 = std.build.Pkg{
        .name = "sdl2",
        .path = "./lib/SDL.zig/src/lib.zig",
    };

    const args = std.build.Pkg{
        .name = "args",
        .path = "./lib/zig-args/args.zig",
    };

    const uri = std.build.Pkg{
        .name = "uri",
        .path = "./lib/zig-uri/uri.zig",
    };

    const painterz = std.build.Pkg{
        .name = "painterz",
        .path = "./lib/painterz/painterz.zig",
    };

    const dunstblick_protocol = std.build.Pkg{
        .name = "dunstblick-protocol",
        .path = "./src/dunstblick-protocol/protocol.zig",
    };

    const dunstblick_app = std.build.Pkg{
        .name = "dunstblick-app",
        .path = "./src/dunstblick-app/dunstblick.zig",
        .dependencies = &[_]std.build.Pkg{
            dunstblick_protocol,
            network,
        },
    };
};

pub fn build(b: *Builder) !void {
    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});

    const compiler = b.addExecutable("dunstblick-compiler", "./src/dunstblick-compiler/main.zig");
    compiler.addPackage(pkgs.args);
    compiler.setTarget(target);
    compiler.setBuildMode(mode);
    compiler.install();

    const compiler_test = b.addTest("./src/dunstblick-compiler/main.zig");

    const lib = b.addStaticLibrary("dunstblick", "./src/libdunstblick/src/c-binding.zig");
    lib.addPackage(pkgs.dunstblick_app);
    lib.addPackage(pkgs.dunstblick_protocol);
    lib.linkLibC();
    lib.setTarget(target);
    lib.setBuildMode(mode);
    lib.install();

    // mediaserver project
    const mediaserver = b.addExecutable("mediaserver", "./src/examples/mediaserver/src/main.zig");
    {
        mediaserver.addIncludeDir("./src/libdunstblick/include");
        mediaserver.addIncludeDir("./src/examples/mediaserver/bass");
        mediaserver.addLibPath("./src/examples/mediaserver/bass/x86_64");
        mediaserver.linkSystemLibrary("bass");
        mediaserver.linkLibrary(lib);
        mediaserver.install();

        const layout_files = [_][]const u8{
            "./src/examples/mediaserver/layouts/main.dui",
            "./src/examples/mediaserver/layouts/menu.dui",
            "./src/examples/mediaserver/layouts/searchlist.dui",
            "./src/examples/mediaserver/layouts/searchitem.dui",
        };
        inline for (layout_files) |infile| {
            const outfile = try std.mem.dupe(b.allocator, u8, infile);
            outfile[outfile.len - 3] = 'c';

            const step = compiler.run();
            step.addArgs(&[_][]const u8{
                infile,
                "-o",
                outfile,
                "-c",
                "./src/examples/mediaserver/layouts/server.json",
            });
            mediaserver.step.dependOn(&step.step);
        }

        mediaserver.linkLibrary(lib);
        mediaserver.setTarget(target);
        mediaserver.setBuildMode(mode);
        mediaserver.install();
    }

    // calculator example
    const calculator = b.addExecutable("calculator", null);
    calculator.addIncludeDir("./src/libdunstblick/include");
    calculator.addCSourceFile("src/examples/calculator/main.c", &[_][]const u8{});
    calculator.linkLibrary(lib);
    calculator.setTarget(target);
    calculator.setBuildMode(mode);
    calculator.install();

    const calculator_headerGen = compiler.run();
    calculator_headerGen.addArgs(&[_][]const u8{
        "./src/examples/calculator/layout.ui",
        "-o",
        "./src/examples/calculator/layout.h",
        "-f",
        "header",
        "-c",
        "./src/examples/calculator/layout.json",
    });
    calculator.step.dependOn(&calculator_headerGen.step);

    // minimal example
    const minimal = b.addExecutable("minimal", null);
    minimal.addIncludeDir("./src/libdunstblick/include");
    minimal.addCSourceFile("src/examples/minimal/main.c", &[_][]const u8{});
    minimal.linkLibrary(lib);
    minimal.setTarget(target);
    minimal.setBuildMode(mode);
    minimal.install();

    const display_client = b.addExecutable("dunstblick-display", "./src/dunstblick-display/main.zig");
    {
        display_client.addPackage(pkgs.dunstblick_protocol);
        display_client.addPackage(pkgs.network);
        display_client.addPackage(pkgs.args);
        display_client.addPackage(pkgs.sdl2);
        display_client.addPackage(pkgs.uri);
        display_client.addPackage(pkgs.painterz);

        display_client.linkLibC();
        display_client.linkSystemLibrary("c++");
        display_client.linkSystemLibrary("sdl2");
        display_client.addIncludeDir("./lib/stb");

        display_client.addIncludeDir("./src/libdunstblick/include");
        display_client.addIncludeDir("./lib/xqlib-stripped/include");
        display_client.addIncludeDir("./lib/optional/include/tl");
        display_client.defineCMacro("DUNSTBLICK_SERVER");
        display_client.setBuildMode(mode);
        display_client.setTarget(target);
        display_client.install();

        display_client.addCSourceFile("./src/dunstblick-display/stb-instantiating.c", &[_][]const u8{
            "-std=c99",
            "-fno-sanitize=undefined",
        });

        for (display_client_sources) |src| {
            display_client.addCSourceFile(src, &[_][]const u8{
                "-std=c++17",
                "-fno-sanitize=undefined",
            });
        }

        for (xqlib_sources) |src| {
            display_client.addCSourceFile(src, &[_][]const u8{
                "-std=c++17",
                "-fno-sanitize=undefined",
            });
        }

        const layout_files = [_][]const u8{
            "./src/dunstblick-display/layouts/discovery-menu.dui",
            "./src/dunstblick-display/layouts/discovery-list-item.dui",
        };
        inline for (layout_files) |infile| {
            const outfile = try std.mem.dupe(b.allocator, u8, infile);
            outfile[outfile.len - 3] = 'c';

            const step = compiler.run();
            step.addArgs(&[_][]const u8{
                infile,
                "-o",
                outfile,
                "-c",
                "./src/dunstblick-display/layouts/resources.json",
            });
            display_client.step.dependOn(&step.step);
        }
    }

    const run_cmd = display_client.run();
    run_cmd.step.dependOn(b.getInstallStep());

    run_cmd.setEnvironmentVariable("LD_LIBRARY_PATH", "./src/examples/mediaserver/bass/x86_64");

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const test_step = b.step("test", "Runs all required tests.");
    test_step.dependOn(&compiler_test.step);
}

const display_client_sources = [_][]const u8{
    "./src/dunstblick-display/widgets.cpp",
    "./src/dunstblick-display/enums.cpp",
    "./src/dunstblick-display/inputstream.cpp",
    "./src/dunstblick-display/layouts.cpp",
    "./src/dunstblick-display/main.cpp",
    "./src/dunstblick-display/zigsession.cpp",
    "./src/dunstblick-display/object.cpp",
    "./src/dunstblick-display/rendercontext.cpp",
    "./src/dunstblick-display/resources.cpp",
    "./src/dunstblick-display/session.cpp",
    "./src/dunstblick-display/types.cpp",
    "./src/dunstblick-display/widget.cpp",
    "./src/dunstblick-display/widget.create.cpp",
};

const xqlib_sources = [_][]const u8{
    "./lib/xqlib-stripped/src/xlog.cpp",
};
