# default-browser-cli

A CLI tool to list installed browsers and manage the default browser.

## Features

- List all installed browsers with their bundle IDs
- Display the current default browser (highlighted in green with `*`)
- Set the default browser for http/https URL schemes

## Supported OS

- [x] macOS
- [ ] Linux
- [ ] Windows

## Requirements

- Zig 0.16.0-dev

## Installation

```bash
git clone https://github.com/devoc09/default-browser-cli.git
cd default-browser-cli
zig build
```

The compiled binary will be available at `zig-out/bin/default-browser-cli`.

## Usage

### List installed browsers

```bash
default-browser-cli list
```

Example output:
```
* com.apple.Safari
  com.google.Chrome
  com.mozilla.firefox
```

The current default browser is marked with `*` and displayed in green.

### Set default browser

```bash
default-browser-cli set <bundle-id>
```

Example:
```bash
default-browser-cli set com.google.Chrome
```

Use the `list` command to see available bundle IDs.

## License

MIT
