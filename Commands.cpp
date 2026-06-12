#include "Commands.h"
#include "LayoutEngine.h"
#include "MacOSWindowBridge.h"
#include <iostream>

namespace miniwm {

// Check if a window matches any rule in the config.
// - "app" rules match the app name exactly.
// - "title" rules match if the window title contains the rule value
//   (substring match). This is more forgiving than exact match and lets
//   rules like "ignore = title:Picture in Picture" work on window titles
//   such as "Zoom Meeting - Picture in Picture".
static bool matchesRule(const WindowInfo& window, const std::vector<ConfigRule>& rules) {
    for (const auto& rule : rules) {
        if (rule.type == "app" && window.appName == rule.value) return true;
        if (rule.type == "title" && window.title.find(rule.value) != std::string::npos) return true;
    }
    return false;
}

int cmdList() {
    auto windows = enumerateWindows();
    if (windows.empty()) {
        std::cout << "No visible windows found.\n";
        return 0;
    }

    std::vector<WindowInfo> infos;
    infos.reserve(windows.size());
    for (const auto& w : windows) {
        infos.push_back(w.info());
    }
    printWindowList(infos);
    return 0;
}

int cmdTile(const Config& config, bool dryRun) {
    auto windows = enumerateWindows();
    if (windows.empty()) {
        std::cout << "No visible windows found.\n";
        return 0;
    }

    Rect screen = getMainScreenVisibleFrame();

    // Filter to only windows that intersect the main screen and are not ignored/floating.
    std::vector<ManagedWindow> tileTargets;
    for (auto& w : windows) {
        const auto& info = w.info();
        if (matchesRule(info, config.ignoreRules)) continue;
        if (matchesRule(info, config.floatRules)) continue;
        if (windowIntersectsScreen(info, screen)) {
            tileTargets.push_back(std::move(w));
        }
    }

    if (tileTargets.empty()) {
        std::cout << "No windows to tile on the main screen.\n";
        return 0;
    }

    auto rects = LayoutEngine::computeLayout(
        (int)tileTargets.size(),
        screen.x, screen.y,
        screen.w, screen.h,
        config.gap,
        config.masterRatio
    );

    if (rects.empty()) {
        std::cerr << "Layout computation failed (screen too small or gap too large).\n";
        return 1;
    }

    for (size_t i = 0; i < tileTargets.size(); i++) {
        const auto& rect = rects[i];
        const auto& info = tileTargets[i].info();

        if (dryRun) {
            std::cout << "[" << i << "] " << info.appName << " - " << info.title
                      << " -> x=" << rect.x << " y=" << rect.y
                      << " w=" << rect.w << " h=" << rect.h << "\n";
        } else {
            bool ok = tileTargets[i].setPositionAndSize(rect.x, rect.y, rect.w, rect.h);
            if (!ok) {
                std::cerr << "Warning: Failed to move/resize window: " << info.title << "\n";
            }
        }
    }

    if (dryRun) {
        std::cout << "Dry run: no changes applied.\n";
    }

    return 0;
}

int cmdConfigTest(const Config& config) {
    printConfig(config);
    return 0;
}

Config cmdReloadConfig() {
    return loadConfig();
}

int cmdFocus(const Config& config, const std::string& direction) {
    auto focused = getFocusedWindow();
    if (focused.pid == 0) {
        std::cerr << "No focused window found.\n";
        return 1;
    }

    auto windows = enumerateWindows();
    if (windows.empty()) {
        std::cerr << "No visible windows found.\n";
        return 1;
    }

    // Find the focused window in the enumerated list. Match by PID, title,
    // and position to disambiguate when multiple windows from the same app
    // share a title (e.g. multiple Terminal windows).
    size_t focusedIndex = windows.size();
    for (size_t i = 0; i < windows.size(); i++) {
        const auto& w = windows[i].info();
        if (w.pid == focused.pid
            && w.title == focused.title
            && w.x == focused.x
            && w.y == focused.y) {
            focusedIndex = i;
            break;
        }
    }

    if (focusedIndex >= windows.size()) {
        std::cerr << "Focused window not found in enumerated list.\n";
        return 1;
    }

    // Find the nearest window in the given direction.
    // Use window center points.
    int bestIndex = -1;
    double bestDistance = 1e9;

    int fx = focused.x + focused.w / 2;
    int fy = focused.y + focused.h / 2;

    for (size_t i = 0; i < windows.size(); i++) {
        if (i == focusedIndex) continue;
        const auto& w = windows[i].info();
        int wx = w.x + w.w / 2;
        int wy = w.y + w.h / 2;

        bool inDirection = false;
        if (direction == "left")   inDirection = wx < fx;
        if (direction == "right")  inDirection = wx > fx;
        if (direction == "up")    inDirection = wy < fy;
        if (direction == "down")  inDirection = wy > fy;

        if (!inDirection) continue;

        double dx = wx - fx;
        double dy = wy - fy;
        double dist = dx * dx + dy * dy;

        if (dist < bestDistance) {
            bestDistance = dist;
            bestIndex = (int)i;
        }
    }

    if (bestIndex < 0) {
        std::cerr << "No window found in direction: " << direction << "\n";
        return 1;
    }

    bool ok = focusWindow(windows[bestIndex].nativeRef());
    if (!ok) {
        std::cerr << "Failed to focus window.\n";
        return 1;
    }

    return 0;
}

int cmdMove(const Config& config, const std::string& direction) {
    // Get the actual focused window AXUIElementRef directly. This avoids
    // fragile PID+title matching that can fail when multiple windows from
    // the same app share the same title.
    AXUIElementRef focusedRef = getFocusedWindowRef();
    if (!focusedRef) {
        std::cerr << "No focused window found.\n";
        return 1;
    }

    int dx = 0, dy = 0;
    const int step = 50;
    if (direction == "left")   dx = -step;
    if (direction == "right")  dx = step;
    if (direction == "up")     dy = -step;
    if (direction == "down")   dy = step;

    bool ok = moveWindowBy(focusedRef, dx, dy);
    CFRelease(focusedRef);
    if (!ok) {
        std::cerr << "Failed to move window.\n";
        return 1;
    }

    return 0;
}

} // namespace miniwm
