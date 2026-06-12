#include "Config.h"
#include <fstream>
#include <iostream>
#include <sstream>

namespace miniwm {

// Default config file path.
static const char* kDefaultConfigPath = "~/.config/miniwm/miniwm.conf";

// Expand ~ to $HOME.
static std::string expandPath(const std::string& path) {
    if (path.empty() || path[0] != '~') return path;
    const char* home = getenv("HOME");
    if (!home) return path;
    return std::string(home) + path.substr(1);
}

// Trim leading and trailing whitespace.
static std::string trim(const std::string& s) {
    size_t start = s.find_first_not_of(" \t\r\n");
    if (start == std::string::npos) return "";
    size_t end = s.find_last_not_of(" \t\r\n");
    return s.substr(start, end - start + 1);
}

// Parse a "bind = alt+shift+r, reload-config" line.
static bool parseBind(const std::string& value, HotkeyBinding& out) {
    size_t comma = value.find(',');
    if (comma == std::string::npos) return false;
    out.modifiers = trim(value.substr(0, comma));
    out.command = trim(value.substr(comma + 1));
    // Split modifiers and key by the last '+'.
    size_t lastPlus = out.modifiers.rfind('+');
    if (lastPlus == std::string::npos) {
        out.key = out.modifiers;
        out.modifiers = "";
    } else {
        out.key = out.modifiers.substr(lastPlus + 1);
        out.modifiers = trim(out.modifiers.substr(0, lastPlus));
    }
    return !out.key.empty() && !out.command.empty();
}

// Parse a "float = app:Calculator" or "ignore = title:Picture in Picture" line.
static bool parseRule(const std::string& value, ConfigRule& out) {
    size_t colon = value.find(':');
    if (colon == std::string::npos) return false;
    out.type = trim(value.substr(0, colon));
    out.value = trim(value.substr(colon + 1));
    return !out.type.empty() && !out.value.empty();
}

Config parseConfig(const std::string& text) {
    Config config;
    std::istringstream stream(text);
    std::string line;
    int lineNum = 0;

    while (std::getline(stream, line)) {
        lineNum++;
        std::string trimmed = trim(line);
        if (trimmed.empty() || trimmed[0] == '#') continue;

        size_t eq = trimmed.find('=');
        if (eq == std::string::npos) {
            std::cerr << "Config line " << lineNum << ": missing '=': " << trimmed << "\n";
            continue;
        }

        std::string key = trim(trimmed.substr(0, eq));
        std::string value = trim(trimmed.substr(eq + 1));

        if (key == "gap") {
            config.gap = std::stoi(value);
        } else if (key == "layout") {
            config.layout = value;
            if (value != "master-stack") {
                std::cerr << "Config: layout '" << value << "' is not supported yet. Falling back to master-stack.\n";
                config.layout = "master-stack";
            }
        } else if (key == "master_ratio") {
            config.masterRatio = std::stod(value);
        } else if (key == "bind") {
            HotkeyBinding binding;
            if (parseBind(value, binding)) {
                config.bindings.push_back(binding);
            } else {
                std::cerr << "Config line " << lineNum << ": invalid bind: " << value << "\n";
            }
        } else if (key == "float") {
            ConfigRule rule;
            if (parseRule(value, rule)) {
                config.floatRules.push_back(rule);
            } else {
                std::cerr << "Config line " << lineNum << ": invalid float: " << value << "\n";
            }
        } else if (key == "ignore") {
            ConfigRule rule;
            if (parseRule(value, rule)) {
                config.ignoreRules.push_back(rule);
            } else {
                std::cerr << "Config line " << lineNum << ": invalid ignore: " << value << "\n";
            }
        } else {
            std::cerr << "Config line " << lineNum << ": unknown key: " << key << "\n";
        }
    }

    return config;
}

Config loadConfig(const std::string& path) {
    std::string configPath = expandPath(path.empty() ? kDefaultConfigPath : path);
    std::ifstream file(configPath);
    if (!file.is_open()) {
        std::cerr << "Config file not found at " << configPath << ", using defaults.\n";
        return Config{};
    }

    std::stringstream buffer;
    buffer << file.rdbuf();
    return parseConfig(buffer.str());
}

void printConfig(const Config& config) {
    std::cout << "=== miniwm config ===\n";
    std::cout << "gap = " << config.gap << "\n";
    std::cout << "layout = " << config.layout << "\n";
    std::cout << "master_ratio = " << config.masterRatio << "\n";
    std::cout << "\nBindings (" << config.bindings.size() << "):\n";
    for (const auto& b : config.bindings) {
        std::cout << "  bind = " << b.modifiers << "+" << b.key << ", " << b.command << "\n";
    }
    std::cout << "\nFloat rules (" << config.floatRules.size() << "):\n";
    for (const auto& r : config.floatRules) {
        std::cout << "  float = " << r.type << ":" << r.value << "\n";
    }
    std::cout << "\nIgnore rules (" << config.ignoreRules.size() << "):\n";
    for (const auto& r : config.ignoreRules) {
        std::cout << "  ignore = " << r.type << ":" << r.value << "\n";
    }
}

} // namespace miniwm
