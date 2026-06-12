#include "Window.h"
#include <iomanip>
#include <iostream>

namespace miniwm {

void printWindowList(const std::vector<WindowInfo>& windows) {
    std::cout << std::left << std::setw(8) << "PID"
              << std::setw(16) << "App Name"
              << std::setw(24) << "Window Title"
              << std::setw(6) << "X"
              << std::setw(6) << "Y"
              << std::setw(6) << "W"
              << std::setw(6) << "H" << "\n";

    for (const auto& w : windows) {
        std::cout << std::left << std::setw(8) << w.pid
                  << std::setw(16) << w.appName
                  << std::setw(24) << w.title
                  << std::setw(6) << w.x
                  << std::setw(6) << w.y
                  << std::setw(6) << w.w
                  << std::setw(6) << w.h << "\n";
    }
}

} // namespace miniwm
