const builtin = @import("builtin");

const impl = switch (builtin.os.tag) {
    .macos => @import("browser/macos.zig"),
    else => @compileError("Unsupported OS"),
};

pub const listInstalledBrowsers = impl.listInstalledBrowsers;
pub const setDefaultBrowser = impl.setDefaultBrowser;
