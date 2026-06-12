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

    // Returns the raw AXUIElementRef. Caller should not release it.
    AXUIElementRef nativeRef() const;

private:
    AXUIElementRef ref_;
    WindowInfo info_;
};

bool checkAccessibilityPermission();
std::vector<ManagedWindow> enumerateWindows();

// Returns the main screen's visible frame in points, converted from
// NSScreen's Cocoa coordinate system (bottom-left origin) to top-left
// global screen coordinates. The returned rect already excludes the
// menu bar and Dock. Safe to pass directly to AXUIElement position/size
// setters, which use the same top-left coordinate space.
Rect getMainScreenVisibleFrame();

// Returns true if the given window bounds intersect the given screen rect.
// Both rects are expected to be in top-left global screen coordinates
// (the same coordinate space used by AX window positions and by
// getMainScreenVisibleFrame()).
bool windowIntersectsScreen(const WindowInfo& window, const Rect& screen);

// Returns the currently focused window (frontmost app + focused window).
// If no focused window is found, returns a WindowInfo with pid == 0.
WindowInfo getFocusedWindow();

// Returns a retained AXUIElementRef for the currently focused window.
// The caller must CFRelease the returned ref when done.
// Returns NULL if no focused window is found.
// This is the most reliable way to refer to the focused window — it
// does not depend on PID+title matching and works even when multiple
// windows from the same app share the same title.
AXUIElementRef getFocusedWindowRef();

// Focus (raise) the given window.
bool focusWindow(AXUIElementRef windowRef);

// Move the given window by a delta (dx, dy).
bool moveWindowBy(AXUIElementRef windowRef, int dx, int dy);

} // namespace miniwm
