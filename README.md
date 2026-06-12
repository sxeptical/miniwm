# miniwm

A simple command-line macOS tiling window manager MVP built with C++ and Objective-C++, inspired by Hyprland's config-file approach.

## What It Does

`miniwm` is not a real compositor. It uses the public macOS Accessibility API to discover, move, resize, and focus normal application windows. It supports four commands:

- `miniwm list` — Print visible windows as a table
- `miniwm tile` — Tile visible windows on the main screen
- `miniwm config-test` — Print the parsed config
- `miniwm daemon` — Run the hotkey daemon for keyboard-driven tiling

## Tiling Behavior

- **1 window:** Fills the screen
- **2 windows:** Left/right split with `master_ratio` controlling the master width
- **3+ windows:** Master window on the left, others stacked vertically on the right
- **Default gap:** 10 pixels
- **Default master_ratio:** 0.55 (master column is 55% of usable width)

## Requirements

- macOS 10.13 or later
- CMake 3.16 or later
- Xcode Command Line Tools (for clang and frameworks)
- **Accessibility permission** — for listing, moving, and focusing windows
- **Input Monitoring permission** — only for the `daemon` command (CGEventTap)

## Build

```bash
mkdir -p build && cd build
cmake ..
make
```

## Run

```bash
./miniwm list
./miniwm tile [--dry-run]
./miniwm config-test
./miniwm daemon
```

## Configuration

`miniwm` reads its config from `~/.config/miniwm/miniwm.conf`. If the file does not exist, default values are used.

### Config Syntax

```ini
# Layout
gap = 10
layout = master-stack
master_ratio = 0.55

# Float/ignore rules
float = app:Calculator
ignore = title:Picture in Picture

# Hotkey bindings
bind = alt+return, tile
bind = alt+shift+r, reload-config
bind = alt+h, focus-left
bind = alt+l, focus-right
bind = alt+j, focus-down
bind = alt+k, focus-up
bind = alt+shift+h, move-left
bind = alt+shift+l, move-right
bind = alt+shift+j, move-down
bind = alt+shift+k, move-up
```

### Supported Keys

- **Modifiers:** `alt` (or `option`), `cmd` (or `command`), `ctrl` (or `control`), `shift`
- **Key names:** `a`–`z`, `0`–`9`, `return`, `tab`, `space`, `esc`, `up`, `down`, `left`, `right`, `delete`, plus common symbols

### Supported Commands

| Command | Description |
|---------|-------------|
| `tile` | Tile all visible windows on the main screen |
| `reload-config` | Reload the config file from disk |
| `focus-left` / `focus-right` / `focus-up` / `focus-down` | Focus the nearest window in that direction |
| `move-left` / `move-right` / `move-up` / `move-down` | Move the focused window by 50px in that direction |

## Grant Permissions

### Accessibility (for `list` and `tile`)

1. Open **System Settings > Privacy & Security > Accessibility**
2. Click the `+` button
3. Add your terminal app (e.g., Terminal, iTerm) or the `miniwm` binary
4. Make sure the toggle is on

### Input Monitoring (for `daemon`)

1. Open **System Settings > Privacy & Security > Input Monitoring**
2. Click the `+` button
3. Add your terminal app or the `miniwm` binary
4. Make sure the toggle is on

## Limitations (MVP)

- **Single monitor only** — Tiles on the main display.
- **Foreground daemon only** — The daemon does not fork or detach. Use `Ctrl+C` to stop.
- **Move step is fixed** — `move-*` commands move by 50px. No layout-order swap yet.
- **Table alignment** — Long app names or window titles may break the column alignment in `list` output.
- **No persistence** — Layout is not remembered between runs.
- **Layout support** — Only `master-stack` is implemented. Other layouts fall back to `master-stack` with a warning.

## Architecture

```
Config.h / .cpp         Config model, parser, ~/.config/miniwm/miniwm.conf loader
Window.h / .cpp         Pure C++ data model (WindowInfo, Rect) and table printer
LayoutEngine.h/.cpp     Pure C++ layout algorithm (master_ratio-aware)
MacOSWindowBridge.h     ManagedWindow RAII class + bridge declarations
MacOSWindowBridge.mm    Objective-C++ AXUIElement/AppKit implementation
Commands.h / .cpp       Reusable command layer (list, tile, focus, move)
HotkeyDaemon.h / .mm    CGEventTap-based daemon with CFRunLoop
main.mm                 CLI dispatcher (list, tile, config-test, daemon)
```

The `LayoutEngine` is pure C++ and does not depend on any macOS APIs. All macOS-specific code is isolated in `MacOSWindowBridge.mm` and `HotkeyDaemon.mm`. The `Commands` layer provides a clean C++ API that the daemon and CLI both consume.

## How It Works

1. **Permission check** — Uses `AXIsProcessTrustedWithOptions` for Accessibility. Daemon also requires Input Monitoring.
2. **Config load** — Reads `~/.config/miniwm/miniwm.conf` at startup. Hotkey `alt+shift+r` reloads it.
3. **Window enumeration** — Iterates `NSWorkspace.runningApplications`, creates an `AXUIElement` for each app, reads windows.
4. **Filtering** — Skips the current process, hidden apps, non-regular apps, minimized windows, popup/menu windows, and tiny windows.
5. **Cross-check** — Validates each AX window against `CGWindowListCopyWindowInfo` to ensure it is on-screen.
6. **Layout filtering** — Applies `float` and `ignore` rules from config during tile selection (not enumeration).
7. **Layout** — Computes rectangle positions for each window using `master_ratio` and `gap`.
8. **Apply** — Uses `AXUIElementSetAttributeValue` to set position and size.
9. **Daemon** — Runs a `CFRunLoop` with a `CGEventTap`. On hotkey press, dispatches to the appropriate `Commands` function.

## Project Status

This is a working MVP. It demonstrates config-driven tiling, focus management, and global hotkeys using only public macOS APIs.

## License

MIT
