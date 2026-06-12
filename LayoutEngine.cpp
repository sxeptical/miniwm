#include "LayoutEngine.h"
#include <algorithm>

namespace miniwm {

// Safe range for masterRatio. Values outside this range produce a degenerate
// layout (one column collapses to 0 width).
static constexpr double kMinMasterRatio = 0.1;
static constexpr double kMaxMasterRatio = 0.9;

std::vector<Rect> LayoutEngine::computeLayout(int count,
                                               int screenX, int screenY,
                                               int screenW, int screenH,
                                               int gap,
                                               double masterRatio) {
    std::vector<Rect> result;
    if (count <= 0) return result;

    // Guard against invalid screen bounds or excessive gap
    if (screenW <= 0 || screenH <= 0 || gap < 0) return result;

    // Clamp masterRatio to a safe range. Even though Config also clamps, this
    // makes LayoutEngine safe to use with any caller.
    if (masterRatio < kMinMasterRatio) masterRatio = kMinMasterRatio;
    if (masterRatio > kMaxMasterRatio) masterRatio = kMaxMasterRatio;

    int innerX = screenX + gap;
    int innerY = screenY + gap;
    int innerW = screenW - 2 * gap;
    int innerH = screenH - 2 * gap;

    // Guard against gap being too large for the screen
    if (innerW <= 0 || innerH <= 0) return result;

    if (count == 1) {
        result.push_back({innerX, innerY, innerW, innerH});
    } else if (count == 2) {
        int masterWidth = (int)((innerW - gap) * masterRatio);
        int stackWidth = innerW - gap - masterWidth;
        if (masterWidth <= 0 || stackWidth <= 0) return result;
        result.push_back({innerX, innerY, masterWidth, innerH}); // Master
        result.push_back({innerX + masterWidth + gap, innerY, stackWidth, innerH});
    } else {
        int masterWidth = (int)((innerW - gap) * masterRatio);
        int stackWidth = innerW - gap - masterWidth;
        if (masterWidth <= 0 || stackWidth <= 0) return result;
        int stackCount = count - 1;
        int stackH = (innerH - (stackCount - 1) * gap) / stackCount;
        if (stackH <= 0) return result;

        result.push_back({innerX, innerY, masterWidth, innerH}); // Master

        for (int i = 0; i < stackCount; i++) {
            result.push_back({
                innerX + masterWidth + gap,
                innerY + i * (stackH + gap),
                stackWidth,
                stackH
            });
        }
    }

    return result;
}

} // namespace miniwm
