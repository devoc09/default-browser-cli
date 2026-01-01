const std = @import("std");
const clap = @import("clap");
const browser = @import("browser.zig");

const SubCommands = enum {
    help,
    list,
    set,
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
        \\  list              List installed browsers
        \\  set <bundle-id>   Set default browser (use 'list' to see IDs)
        \\  help              Display this help
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
            std.debug.print("Unknown command. Available commands: help, list, set\n", .{});
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
        .set => try setMain(gpa, &iter, res),
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

fn setMain(gpa: std.mem.Allocator, iter: *std.process.ArgIterator, main_args: MainArgs) !void {
    _ = main_args;

    const set_parsers = .{
        .bundleId = clap.parsers.string,
    };

    const params = comptime clap.parseParamsComptime(
        \\-h, --help    Display this help and exit.
        \\<bundleId>
    );

    var threaded: std.Io.Threaded = .init_single_threaded;
    const io: std.Io = threaded.io();

    var diag = clap.Diagnostic{};
    var res = clap.parseEx(clap.Help, &params, set_parsers, iter, .{
        .diagnostic = &diag,
        .allocator = gpa,
    }) catch |err| {
        try diag.reportToFile(io, .stderr(), err);
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        std.debug.print(
            \\Usage: default-browser-cli set <bundle-id>
            \\
            \\Set the default browser. Use 'list' to see available browser IDs.
            \\
            \\Options:
            \\  -h, --help    Display this help and exit
            \\
        , .{});
        return;
    }

    const bundleId = res.positionals[0] orelse {
        std.debug.print("Error: missing required argument: <bundle-id>\n", .{});
        std.process.exit(1);
    };

    // TTY check
    const stdin: std.Io.File = .stdin();
    if (stdin.isTty(io)) |is_tty| {
        if (!is_tty) {
            std.debug.print("Error: TTY required. Run in a terminal.\n", .{});
            std.process.exit(1);
        }
    } else |_| {
        std.debug.print("Error: TTY required. Run in a terminal.\n", .{});
        std.process.exit(1);
    }

    // Get installed browser IDs and validate
    const installedIds = browser.getInstalledBrowserIds(gpa) catch {
        std.debug.print("Error: failed to get installed browsers\n", .{});
        std.process.exit(1);
    };
    defer {
        for (installedIds) |id| {
            gpa.free(id);
        }
        gpa.free(installedIds);
    }

    var found = false;
    for (installedIds) |id| {
        if (std.mem.eql(u8, id, bundleId)) {
            found = true;
            break;
        }
    }

    if (!found) {
        std.debug.print("Error: browser not found: {s}\n", .{bundleId});
        std.process.exit(1);
    }

    // Check if already default
    var defaultBuffer: [256]u8 = undefined;
    if (browser.getDefaultBrowser(&defaultBuffer)) |currentDefault| {
        if (std.mem.eql(u8, currentDefault, bundleId)) {
            // Already default, exit silently with success
            return;
        }
    }

    // Set the default browser
    const bundleIdZ = gpa.dupeZ(u8, bundleId) catch {
        std.debug.print("Error: memory allocation failed\n", .{});
        std.process.exit(1);
    };
    defer gpa.free(bundleIdZ);

    browser.setDefaultBrowser(bundleIdZ) catch {
        std.process.exit(1);
    };
}
