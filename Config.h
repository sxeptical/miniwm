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

    // Populate the default keybindings (used when no config file is present
    // or when the file does not define any bindings). This ensures the
    // daemon is usable out of the box.
    void setDefaultBindings() {
        bindings.clear();
        // Layout and config management
        bindings.push_back({"alt",       "return", "tile"});
        bindings.push_back({"alt+shift", "r",      "reload-config"});
        // Focus movement
        bindings.push_back({"alt", "h", "focus-left"});
        bindings.push_back({"alt", "l", "focus-right"});
        bindings.push_back({"alt", "j", "focus-down"});
        bindings.push_back({"alt", "k", "focus-up"});
        // Window movement
        bindings.push_back({"alt+shift", "h", "move-left"});
        bindings.push_back({"alt+shift", "l", "move-right"});
        bindings.push_back({"alt+shift", "j", "move-down"});
        bindings.push_back({"alt+shift", "k", "move-up"});
    }
};

// Load config from the default path (~/.config/miniwm/miniwm.conf).
// If the file does not exist, returns the default config.
Config loadConfig(const std::string& path = "");

// Parse a config string (for testing).
Config parseConfig(const std::string& text);

// Print parsed config in a human-readable format.
void printConfig(const Config& config);

} // namespace miniwm
