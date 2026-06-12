#pragma once
#include <string>
#include <vector>

namespace miniwm {

struct HotkeyBinding {
    // "alt", "alt+shift", "ctrl", "cmd", etc.
    std::string modifiers;
    // "h", "return", "r", etc.
    std::string key;
    // "tile", "focus-left", "reload-config", etc.
    std::string command;
};

struct ConfigRule {
    // "app" or "title"
    std::string type;
    // e.g. "Calculator", "System Settings", "Picture in Picture"
    std::string value;
};

struct Config {
    int gap = 10;
    std::string layout = "master-stack";
    double masterRatio = 0.55;

    std::vector<HotkeyBinding> bindings;
    std::vector<ConfigRule> floatRules;
    std::vector<ConfigRule> ignoreRules;
};

// Load config from the default path (~/.config/miniwm/miniwm.conf).
// If the file does not exist, returns the default config.
Config loadConfig(const std::string& path = "");

// Parse a config string (for testing).
Config parseConfig(const std::string& text);

// Print parsed config in a human-readable format.
void printConfig(const Config& config);

} // namespace miniwm
