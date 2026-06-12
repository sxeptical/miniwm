#pragma once
#include "Window.h"
#include <vector>

namespace miniwm {

class LayoutEngine {
public:
    static std::vector<Rect> computeLayout(int windowCount,
                                            int screenX, int screenY,
                                            int screenW, int screenH,
                                            int gap,
                                            double masterRatio = 0.55);
};

} // namespace miniwm
