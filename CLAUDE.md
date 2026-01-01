# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

```bash
zig build              # Build the project
```

The compiled binary is output to `zig-out/bin/default-browser-cli`.

## Project Structure

A macOS CLI tool written in Zig that lists installed browsers and manages the default browser:

- **`src/main.zig`** - CLI entry point and argument parsing using zig-clap
- **`src/browser.zig`** - Platform abstraction layer with OS-conditional compilation
- **`src/browser/macos.zig`** - macOS implementation using Core Foundation/Launch Services FFI

## Architecture Notes

### CLI Subcommands

- `list` - Lists all installed browsers (default browser shown in green with `*`)
- `set <bundle-id>` - Sets the default browser for http/https schemes
- `help` - Displays usage information

### macOS API Integration

The project calls macOS Launch Services directly via Zig's C FFI:
- `LSCopyAllHandlersForURLScheme()` - Get all browsers handling https
- `LSCopyDefaultHandlerForURLScheme()` - Get current default browser
- `LSSetDefaultHandlerForURLScheme()` - Set default browser (sets both http and https)

### Platform System

- Uses `@import("builtin").os.tag` for OS-conditional compilation
- Currently macOS only; `browser.zig` provides the abstraction point for future OS support
- Links CoreServices framework at build time

### Dependencies

- Uses a forked zig-clap from `devoc09/zig-clap` for argument parsing
- Requires Zig 0.15.1+
