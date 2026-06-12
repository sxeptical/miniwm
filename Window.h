#pragma once
#include <string>
#include <vector>

namespace miniwm {

struct WindowInfo {
    int pid = 0;
    std::string appName;
    std::string title;
    int x = 0;
    int y = 0;
    int w = 0;
    int h = 0;
};

struct Rect {
    int x = 0;
    int y = 0;
    int w = 0;
    int h = 0;
};

void printWindowList(const std::vector<WindowInfo>& windows);

} // namespace miniwm
