#include "MacOSWindowBridge.h"
#include "LayoutEngine.h"
#include "Window.h"
#include <cstdlib>
#include <iostream>
#include <string>
#include <vector>

struct CommandOptions {
    bool dryRun = false;
    int gap = 10;
};

void printUsage(const char* programName) {
    std::cerr << "Usage:\n"
              << "  " << programName << " list [--json]\n"
              << "  " << programName << " tile [--gap <pixels>] [--dry-run]\n"
              << "\n"
              << "Commands:\n"
              << "  list    List visible windows in a table.\n"
              << "  tile    Tile visible windows on the main screen.\n"
              << "\n"
              << "Options:\n"
              << "  --gap <n>     Gap between windows in pixels (default: 10).\n"
              << "  --dry-run     For 'tile': print intended positions without applying them.\n"
              << "  --json        For 'list': output as JSON (not yet implemented).\n";
}

// Parse options for the given command starting at argv[index].
// Returns true on success, false on parse error.
bool parseOptions(const std::string& cmd, int argc, char* argv[], int startIndex, CommandOptions& opts, std::string& error) {
    for (int i = startIndex; i < argc; i++) {
        std::string arg = argv[i];

        if (arg == "--dry-run") {
            if (cmd != "tile") {
                error = "--dry-run is only valid with 'tile'";
                return false;
            }
            opts.dryRun = true;
        } else if (arg == "--gap") {
            if (cmd != "tile") {
                error = "--gap is only valid with 'tile'";
                return false;
            }
            if (i + 1 >= argc) {
                error = "--gap requires a numeric argument";
                return false;
            }
            i++;
            std::string value = argv[i];
            char* end = nullptr;
            long n = std::strtol(value.c_str(), &end, 10);
            if (end == value.c_str() || *end != '\0' || n < 0 || n > 10000) {
                error = "--gap value must be a non-negative integer (0-10000)";
                return false;
            }
            opts.gap = (int)n;
        } else if (arg == "--json") {
            if (cmd != "list") {
                error = "--json is only valid with 'list'";
                return false;
            }
            error = "--json is not yet implemented";
            return false;
        } else {
            error = "Unknown option: " + arg;
            return false;
        }
    }
    return true;
}

int runList() {
    // Extract WindowInfo for display
    auto windows = miniwm::enumerateWindows();
    if (windows.empty()) {
        std::cout << "No visible windows found.\n";
        return 0;
    }

    std::vector<miniwm::WindowInfo> infos;
    infos.reserve(windows.size());
    for (const auto& w : windows) {
        infos.push_back(w.info());
    }
    miniwm::printWindowList(infos);
    return 0;
}

int runTile(const CommandOptions& opts) {
    auto windows = miniwm::enumerateWindows();
    if (windows.empty()) {
        std::cout << "No visible windows found.\n";
        return 0;
    }

    // Get main screen's visible frame (excludes menu bar and Dock)
    miniwm::Rect screen = miniwm::getMainScreenVisibleFrame();

    // Filter to only windows that intersect the main screen
    std::vector<miniwm::ManagedWindow> tileTargets;
    for (auto& w : windows) {
        if (miniwm::windowIntersectsScreen(w.info(), screen)) {
            tileTargets.push_back(std::move(w));
        }
    }

    if (tileTargets.empty()) {
        std::cout << "No windows to tile on the main screen.\n";
        return 0;
    }

    // Compute layout rectangles
    auto rects = miniwm::LayoutEngine::computeLayout(
        (int)tileTargets.size(),
        screen.x, screen.y,
        screen.w, screen.h,
        opts.gap
    );

    if (rects.empty()) {
        std::cerr << "Layout computation failed (screen too small or gap too large).\n";
        return 1;
    }

    // Apply (or print) the layout
    for (size_t i = 0; i < tileTargets.size(); i++) {
        const auto& rect = rects[i];
        const auto& info = tileTargets[i].info();

        if (opts.dryRun) {
            std::cout << "[" << i << "] " << info.appName << " - " << info.title
                      << " -> x=" << rect.x << " y=" << rect.y
                      << " w=" << rect.w << " h=" << rect.h << "\n";
        } else {
            bool ok = tileTargets[i].setPositionAndSize(rect.x, rect.y, rect.w, rect.h);
            if (!ok) {
                std::cerr << "Warning: Failed to move/resize window: "
                          << info.title << "\n";
            }
        }
    }

    if (opts.dryRun) {
        std::cout << "Dry run: no changes applied.\n";
    }

    return 0;
}

int main(int argc, char* argv[]) {
    if (argc < 2) {
        printUsage(argv[0]);
        return 1;
    }

    std::string cmd = argv[1];

    // Validate command before requesting Accessibility permission
    if (cmd != "list" && cmd != "tile") {
        std::cerr << "Unknown command: " << cmd << "\n";
        printUsage(argv[0]);
        return 1;
    }

    // Parse options (everything after the command)
    CommandOptions opts;
    std::string error;
    if (!parseOptions(cmd, argc, argv, 2, opts, error)) {
        std::cerr << "Error: " << error << "\n";
        printUsage(argv[0]);
        return 1;
    }

    // Check Accessibility permission (only for commands that need it)
    if (!miniwm::checkAccessibilityPermission()) {
        std::cerr << "Accessibility permission required.\n"
                  << "Please enable it in:\n"
                  << "System Settings > Privacy & Security > Accessibility\n";
        return 1;
    }

    if (cmd == "list") {
        return runList();
    } else {
        return runTile(opts);
    }
}
