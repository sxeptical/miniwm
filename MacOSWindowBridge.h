#pragma once
#include "Window.h"
#include <vector>
#include <ApplicationServices/ApplicationServices.h>

namespace miniwm {

class ManagedWindow {
public:
    ManagedWindow(AXUIElementRef ref, const WindowInfo& info);
    ~ManagedWindow();

    ManagedWindow(const ManagedWindow&) = delete;
    ManagedWindow& operator=(const ManagedWindow&) = delete;

    ManagedWindow(ManagedWindow&& other) noexcept;
    ManagedWindow& operator=(ManagedWindow&& other) noexcept;

    const WindowInfo& info() const;
    bool setPositionAndSize(int x, int y, int w, int h) const;

private:
    AXUIElementRef ref_;
    WindowInfo info_;
};

bool checkAccessibilityPermission();
std::vector<ManagedWindow> enumerateWindows();

// Returns the main screen's visible frame in points, with origin at the
// bottom-left (Cocoa coordinate system). Already excludes the menu bar and Dock.
Rect getMainScreenVisibleFrame();

// Returns true if the given window bounds (in Cocoa coordinates, top-left origin)
// intersect the given screen rect. Both rects are in the same coordinate space.
bool windowIntersectsScreen(const WindowInfo& window, const Rect& screen);

} // namespace miniwm
