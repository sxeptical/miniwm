#include "LayoutEngine.h"

namespace miniwm {

std::vector<Rect> LayoutEngine::computeLayout(int count,
                                               int screenX, int screenY,
                                               int screenW, int screenH,
                                               int gap) {
    std::vector<Rect> result;
    if (count <= 0) return result;

    int innerX = screenX + gap;
    int innerY = screenY + gap;
    int innerW = screenW - 2 * gap;
    int innerH = screenH - 2 * gap;

    if (count == 1) {
        result.push_back({innerX, innerY, innerW, innerH});
    } else if (count == 2) {
        int colW = (innerW - gap) / 2;
        result.push_back({innerX, innerY, colW, innerH});
        result.push_back({innerX + colW + gap, innerY, colW, innerH});
    } else {
        int colW = (innerW - gap) / 2;
        int stackCount = count - 1;
        int stackH = (innerH - (stackCount - 1) * gap) / stackCount;

        result.push_back({innerX, innerY, colW, innerH}); // Master

        for (int i = 0; i < stackCount; i++) {
            result.push_back({
                innerX + colW + gap,
                innerY + i * (stackH + gap),
                colW,
                stackH
            });
        }
    }

    return result;
}

} // namespace miniwm
