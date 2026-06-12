# miniwm

A simple command-line macOS tiling window manager MVP built with C++ and Objective-C++.

## What It Does

`miniwm` is not a real compositor. It uses the public macOS Accessibility API to discover, move, and resize normal application windows. It supports two commands:

- `miniwm list` — Print visible windows as a table
- `miniwm tile` — Tile visible windows on the main screen

## Tiling Behavior

- **1 window:** Fills the screen
- **2 windows:** Left/right split
- **3+ windows:** Master window on the left, others stacked vertically on the right
- **Default gap:** 10 pixels

## Requirements

- macOS 10.13 or later
- CMake 3.16 or later
- Xcode Command Line Tools (for clang and frameworks)
- Accessibility permission (granted to the terminal or the `miniwm` binary)

## Build

```bash
mkdir -p build && cd build
cmake ..
make
```

## Run

```bash
./miniwm list
./miniwm tile
```

## Grant Accessibility Permission

On first run, macOS will prompt you to grant Accessibility permission. If the prompt does not appear or you previously denied it:

1. Open **System Settings > Privacy & Security > Accessibility**
2. Click the `+` button
3. Add your terminal app (e.g., Terminal, iTerm) or the `miniwm` binary
4. Make sure the toggle is on
5. Run `./miniwm list` again

## Limitations (MVP)

- **Single monitor only** — Tiles on the main display.
- **Menu bar and Dock overlap** — Tiled windows may overlap the menu bar and Dock. Future versions will use `NSScreen.visibleFrame` to respect these areas.
- **Table alignment** — Long app names or window titles may break the column alignment in `list` output.
- **No persistence** — Layout is not remembered between runs.

## Architecture

```
main.mm              CLI entry point, command dispatch
Window.h / .cpp      Pure C++ data model (WindowInfo, Rect) and table printer
LayoutEngine.h/.cpp  Pure C++ layout algorithm
MacOSWindowBridge.h  ManagedWindow RAII class + bridge declarations
MacOSWindowBridge.mm Objective-C++ implementation (AXUIElement, AppKit)
```

The `LayoutEngine` is pure C++ and does not depend on any macOS APIs, so it can be unit tested independently. All macOS-specific code is isolated in `MacOSWindowBridge.mm`.

## How It Works

1. **Permission check** — Uses `AXIsProcessTrustedWithOptions` to verify Accessibility permission. If denied, prints instructions and exits with code `1`.
2. **Window enumeration** — Iterates `NSWorkspace.runningApplications`, creates an `AXUIElement` for each app, and reads its windows via `kAXWindowsAttribute`.
3. **Filtering** — Skips the current process, hidden apps, non-regular apps, minimized windows, popup/menu windows, and tiny windows.
4. **Cross-check** — Validates each AX window against `CGWindowListCopyWindowInfo` to ensure it is actually on-screen.
5. **Layout** — Computes rectangle positions for each window using the rules above.
6. **Apply** — Uses `AXUIElementSetAttributeValue` to set the position and size of each window.

## Project Status

This is a working MVP. It is not a replacement for full-featured tiling window managers like yabai or Amethyst, but it demonstrates the core concepts and provides a foundation for further development.

## License

MIT
