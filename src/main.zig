const std = @import("std");
const clap = @import("clap");
const browser = @import("browser.zig");

const SubCommands = enum {
    help,
    list,
};

const main_parsers = .{
    .command = clap.parsers.enumeration(SubCommands),
};

const main_params = clap.parseParamsComptime(
    \\-h, --help    Display this help and exit.
    \\<command>
    \\
);

const MainArgs = clap.ResultEx(clap.Help, &main_params, main_parsers);

fn printUsage() void {
    std.debug.print(
        \\Usage: default-browser-cli <command> [options]
        \\
        \\Commands:
        \\  list    List installed browsers
        \\  help    Display this help
        \\
        \\Options:
        \\  -h, --help    Display this help and exit
        \\
    , .{});
}

pub fn main() !void {
    var gpa_state = std.heap.DebugAllocator(.{}){};
    const gpa = gpa_state.allocator();
    defer _ = gpa_state.deinit();

    var iter = try std.process.ArgIterator.initWithAllocator(gpa);
    defer iter.deinit();
    _ = iter.next(); // skip program name

    var threaded: std.Io.Threaded = .init_single_threaded;
    const io: std.Io = threaded.io();

    var diag = clap.Diagnostic{};
    var res = clap.parseEx(clap.Help, &main_params, main_parsers, &iter, .{
        .diagnostic = &diag,
        .allocator = gpa,
        .terminating_positional = 0,
    }) catch |err| {
        if (err == error.NameNotPartOfEnum) {
            std.debug.print("Unknown command. Available commands: help, list\n", .{});
            return;
        }
        try diag.reportToFile(io, .stderr(), err);
        return;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        printUsage();
        return;
    }

    const command = res.positionals[0] orelse {
        printUsage();
        return;
    };
    switch (command) {
        .help => printUsage(),
        .list => try listMain(gpa, &iter, res),
    }
}

fn listMain(gpa: std.mem.Allocator, iter: *std.process.ArgIterator, main_args: MainArgs) !void {
    _ = main_args;

    const params = comptime clap.parseParamsComptime(
        \\-h, --help    Display this help and exit.
    );

    var threaded: std.Io.Threaded = .init_single_threaded;
    const io: std.Io = threaded.io();

    var diag = clap.Diagnostic{};
    var res = clap.parseEx(clap.Help, &params, clap.parsers.default, iter, .{
        .diagnostic = &diag,
        .allocator = gpa,
    }) catch |err| {
        try diag.reportToFile(io, .stderr(), err);
        return err;
    };

    defer res.deinit();

    try browser.listInstalledBrowsers();
    return;
}
