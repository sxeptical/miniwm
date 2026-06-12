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

} // namespace miniwm
