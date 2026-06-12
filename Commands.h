#pragma once
#include "Config.h"
#include "Window.h"

namespace miniwm {

// List visible windows.
int cmdList();

// Tile visible windows on the main screen.
// If dryRun is true, prints intended positions without applying.
int cmdTile(const Config& config, bool dryRun);

// Print parsed config.
int cmdConfigTest(const Config& config);

// Focus the nearest window in the given direction.
// Directions: "left", "right", "up", "down".
int cmdFocus(const Config& config, const std::string& direction);

// Move the currently focused window by a fixed amount in the given direction.
// Directions: "left", "right", "up", "down".
int cmdMove(const Config& config, const std::string& direction);

// Reload config from disk and return the new config.
Config cmdReloadConfig();

} // namespace miniwm
