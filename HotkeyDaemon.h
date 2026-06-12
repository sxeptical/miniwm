#pragma once
#include "Config.h"

namespace miniwm {

// Start the hotkey daemon. Runs a CFRunLoop with a CGEventTap.
// Blocks until the daemon is stopped (e.g., Ctrl+C).
// Returns 0 on clean exit, 1 on error.
int runDaemon(const Config& config);

} // namespace miniwm
