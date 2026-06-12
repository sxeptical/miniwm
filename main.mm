#include "MacOSWindowBridge.h"
#include "LayoutEngine.h"
#include "Window.h"
#include <CoreGraphics/CoreGraphics.h>
#include <iostream>
#include <vector>

int main(int argc, char* argv[]) {
    if (argc < 2) {
        std::cerr << "Usage: miniwm <list|tile>\n";
        return 1;
    }

    std::string cmd = argv[1];

    // Check Accessibility permission
    if (!miniwm::checkAccessibilityPermission()) {
        std::cerr << "Accessibility permission required.\n"
                  << "Please enable it in:\n"
                  << "System Settings > Privacy & Security > Accessibility\n";
        return 1;
    }

    // Enumerate all visible windows
    auto windows = miniwm::enumerateWindows();

    if (windows.empty()) {
        std::cout << "No visible windows found.\n";
        return 0;
    }

    if (cmd == "list") {
        // Extract WindowInfo for display
        std::vector<miniwm::WindowInfo> infos;
        infos.reserve(windows.size());
        for (const auto& w : windows) {
            infos.push_back(w.info());
        }
        miniwm::printWindowList(infos);

    } else if (cmd == "tile") {
        // Get main display bounds
        // NOTE: CGDisplayBounds includes menu bar and Dock area.
        // Future: use NSScreen.visibleFrame to avoid overlap.
        CGDirectDisplayID mainDisplay = CGMainDisplayID();
        CGRect screen = CGDisplayBounds(mainDisplay);

        // Compute layout rectangles
        auto rects = miniwm::LayoutEngine::computeLayout(
            (int)windows.size(),
            (int)screen.origin.x, (int)screen.origin.y,
            (int)screen.size.width, (int)screen.size.height,
            10  // gap
        );

        // Apply layout to each window
        for (size_t i = 0; i < windows.size(); i++) {
            const auto& rect = rects[i];
            bool ok = windows[i].setPositionAndSize(rect.x, rect.y, rect.w, rect.h);
            if (!ok) {
                std::cerr << "Warning: Failed to move/resize window: "
                          << windows[i].info().title << "\n";
            }
        }

    } else {
        std::cerr << "Unknown command: " << cmd << "\n";
        return 1;
    }

    return 0;
}
