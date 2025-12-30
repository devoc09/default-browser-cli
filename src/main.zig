const std = @import("std");

// Core Foundation / Launch Services の型と関数を定義
const CFStringRef = *opaque {};
const CFArrayRef = *opaque {};
const CFAllocatorRef = ?*opaque {};
const OSStatus = i32;

// Core Foundation の外部関数
extern "c" fn CFStringCreateWithCString(
    alloc: CFAllocatorRef,
    cStr: [*:0]const u8,
    encoding: u32,
) ?CFStringRef;

extern "c" fn CFRelease(cf: ?*anyopaque) void;

// CFArray 操作
extern "c" fn CFArrayGetCount(theArray: CFArrayRef) isize;
extern "c" fn CFArrayGetValueAtIndex(theArray: CFArrayRef, idx: isize) ?*anyopaque;

// CFString から C文字列への変換
extern "c" fn CFStringGetCString(
    theString: CFStringRef,
    buffer: [*]u8,
    bufferSize: isize,
    encoding: u32,
) bool;

// Launch Services の外部関数
extern "c" fn LSSetDefaultHandlerForURLScheme(
    inURLScheme: CFStringRef,
    inHandlerBundleID: CFStringRef,
) OSStatus;

extern "c" fn LSCopyDefaultHandlerForURLScheme(
    inURLScheme: CFStringRef,
) ?CFStringRef;

extern "c" fn LSCopyAllHandlersForURLScheme(
    inURLScheme: CFStringRef,
) ?CFArrayRef;

// kCFStringEncodingUTF8 = 0x08000100
const kCFStringEncodingUTF8: u32 = 0x08000100;

fn createCFString(str: [*:0]const u8) ?CFStringRef {
    return CFStringCreateWithCString(null, str, kCFStringEncodingUTF8);
}

fn cfStringToSlice(cfStr: CFStringRef, buffer: []u8) ?[]const u8 {
    if (CFStringGetCString(cfStr, buffer.ptr, @intCast(buffer.len), kCFStringEncodingUTF8)) {
        const len = std.mem.indexOfScalar(u8, buffer, 0) orelse buffer.len;
        return buffer[0..len];
    }
    return null;
}

pub fn listInstalledBrowsers() !void {
    const schemeCFString = createCFString("https") orelse return error.CFStringCreationFailed;
    defer CFRelease(schemeCFString);

    // 現在のデフォルトブラウザを取得
    const defaultHandler = LSCopyDefaultHandlerForURLScheme(schemeCFString);
    defer if (defaultHandler) |h| CFRelease(h);

    var defaultBundleId: [256]u8 = undefined;
    var defaultSlice: ?[]const u8 = null;
    if (defaultHandler) |handler| {
        defaultSlice = cfStringToSlice(handler, &defaultBundleId);
    }

    // 全ハンドラを取得
    const handlers = LSCopyAllHandlersForURLScheme(schemeCFString) orelse {
        std.debug.print("No browsers found.\n", .{});
        return;
    };
    defer CFRelease(handlers);

    const count = CFArrayGetCount(handlers);
    std.debug.print("Installed browsers:\n", .{});

    var i: isize = 0;
    while (i < count) : (i += 1) {
        const value = CFArrayGetValueAtIndex(handlers, i) orelse continue;
        const bundleIdCFString: CFStringRef = @ptrCast(value);

        var buffer: [256]u8 = undefined;
        if (cfStringToSlice(bundleIdCFString, &buffer)) |bundleId| {
            const isDefault = if (defaultSlice) |def| std.mem.eql(u8, bundleId, def) else false;
            if (isDefault) {
                std.debug.print("  * {s} (default)\n", .{bundleId});
            } else {
                std.debug.print("    {s}\n", .{bundleId});
            }
        }
    }
}

pub fn setDefaultBrowser(bundleId: [*:0]const u8) !void {
    const browserCFString = createCFString(bundleId) orelse return error.CFStringCreationFailed;
    defer CFRelease(browserCFString);

    const schemes = [_][*:0]const u8{ "http", "https" };

    for (schemes) |scheme| {
        const schemeCFString = createCFString(scheme) orelse return error.CFStringCreationFailed;
        defer CFRelease(schemeCFString);

        const status = LSSetDefaultHandlerForURLScheme(schemeCFString, browserCFString);
        if (status != 0) {
            std.debug.print("Failed to set handler for {s}: error {d}\n", .{ scheme, status });
            return error.LSSetHandlerFailed;
        }
    }

    std.debug.print("Default browser set to: {s}\n", .{bundleId});
}

pub fn main() !void {
    var args = std.process.args();
    _ = args.skip(); // プログラム名をスキップ

    const arg = args.next();
    if (arg) |a| {
        if (std.mem.eql(u8, a, "--list") or std.mem.eql(u8, a, "-l")) {
            try listInstalledBrowsers();
            return;
        }
    }

    // 使い方を表示
    std.debug.print("Usage: default-browser-cli [options]\n", .{});
    std.debug.print("Options:\n", .{});
    std.debug.print("  -l, --list    List installed browsers\n", .{});
}
