#include "HotkeyDaemon.h"
#include "Commands.h"
#include <CoreGraphics/CoreGraphics.h>
#include <iostream>
#include <map>
#include <string>

namespace miniwm {

// Map from key string to CGKeyCode.
static std::map<std::string, CGKeyCode> kKeyCodeMap = {
    {"a", 0}, {"s", 1}, {"d", 2}, {"f", 3}, {"h", 4}, {"g", 5},
    {"z", 6}, {"x", 7}, {"c", 8}, {"v", 9}, {"b", 11}, {"q", 12},
    {"w", 13}, {"e", 14}, {"r", 15}, {"y", 16}, {"t", 17}, {"1", 18},
    {"2", 19}, {"3", 20}, {"4", 21}, {"6", 22}, {"5", 23}, {"=", 24},
    {"9", 25}, {"7", 26}, {"-", 27}, {"8", 28}, {"0", 29}, {"]", 30},
    {"o", 31}, {"u", 32}, {"[", 33}, {"i", 34}, {"p", 35}, {"return", 36},
    {"l", 37}, {"j", 38}, {"'", 39}, {"k", 40}, {";", 41}, {"\\", 42},
    {",", 43}, {"/", 44}, {"n", 45}, {"m", 46}, {".", 47}, {"tab", 48},
    {"space", 49}, {"`", 50}, {"delete", 51}, {"enter", 52}, {"esc", 53},
    {"right", 124}, {"left", 123}, {"down", 125}, {"up", 126},
};

static CGKeyCode keyCodeForString(const std::string& key) {
    auto it = kKeyCodeMap.find(key);
    if (it != kKeyCodeMap.end()) return it->second;
    if (key.length() == 1) {
        char c = key[0];
        if (c >= 'a' && c <= 'z') {
            auto it2 = kKeyCodeMap.find(std::string(1, c));
            if (it2 != kKeyCodeMap.end()) return it2->second;
        }
    }
    return 0xFF; // Invalid
}

static CGEventFlags modifierFlagsForString(const std::string& modifiers) {
    CGEventFlags flags = 0;
    if (modifiers.find("cmd") != std::string::npos || modifiers.find("command") != std::string::npos)
        flags |= kCGEventFlagMaskCommand;
    if (modifiers.find("alt") != std::string::npos || modifiers.find("option") != std::string::npos)
        flags |= kCGEventFlagMaskAlternate;
    if (modifiers.find("ctrl") != std::string::npos || modifiers.find("control") != std::string::npos)
        flags |= kCGEventFlagMaskControl;
    if (modifiers.find("shift") != std::string::npos)
        flags |= kCGEventFlagMaskShift;
    return flags;
}

// Global state for the callback.
static Config gConfig;

static void dispatchCommand(const std::string& cmd) {
    std::cout << "[daemon] Hotkey triggered: " << cmd << "\n";

    if (cmd == "tile") {
        cmdTile(gConfig, false);
    } else if (cmd == "reload-config") {
        gConfig = cmdReloadConfig();
        std::cout << "[daemon] Config reloaded.\n";
    } else if (cmd == "focus-left") {
        cmdFocus(gConfig, "left");
    } else if (cmd == "focus-right") {
        cmdFocus(gConfig, "right");
    } else if (cmd == "focus-up") {
        cmdFocus(gConfig, "up");
    } else if (cmd == "focus-down") {
        cmdFocus(gConfig, "down");
    } else if (cmd == "move-left") {
        cmdMove(gConfig, "left");
    } else if (cmd == "move-right") {
        cmdMove(gConfig, "right");
    } else if (cmd == "move-up") {
        cmdMove(gConfig, "up");
    } else if (cmd == "move-down") {
        cmdMove(gConfig, "down");
    } else {
        std::cerr << "[daemon] Unknown command: " << cmd << "\n";
    }
}

static CGEventRef eventTapCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void* refcon) {
    if (type != kCGEventKeyDown && type != kCGEventFlagsChanged) {
        return event;
    }

    CGKeyCode keyCode = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
    CGEventFlags flags = CGEventGetFlags(event);

    // Keep only modifier flags.
    flags &= (kCGEventFlagMaskCommand | kCGEventFlagMaskAlternate | kCGEventFlagMaskControl | kCGEventFlagMaskShift);

    for (const auto& binding : gConfig.bindings) {
        CGKeyCode expectedKey = keyCodeForString(binding.key);
        if (expectedKey == 0xFF) continue;

        CGEventFlags expectedFlags = modifierFlagsForString(binding.modifiers);

        if (keyCode == expectedKey && flags == expectedFlags) {
            dispatchCommand(binding.command);
            // Consume the event so the app doesn't also receive it.
            return nullptr;
        }
    }

    return event;
}

int runDaemon(const Config& config) {
    gConfig = config;

    std::cout << "[daemon] Starting miniwm daemon...\n";
    std::cout << "[daemon] Loaded " << gConfig.bindings.size() << " hotkey bindings.\n";

    CFMachPortRef tap = CGEventTapCreate(
        kCGSessionEventTap,
        kCGHeadInsertEventTap,
        kCGEventTapOptionDefault,
        CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(kCGEventFlagsChanged),
        eventTapCallback,
        nullptr
    );

    if (!tap) {
        std::cerr << "[daemon] Failed to create event tap.\n"
                  << "This usually means Input Monitoring permission is missing.\n"
                  << "Please enable it in:\n"
                  << "System Settings > Privacy & Security > Input Monitoring\n";
        return 1;
    }

    CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
    CGEventTapEnable(tap, true);

    std::cout << "[daemon] Event tap enabled. Press Ctrl+C to stop.\n";

    CFRunLoopRun();

    // Cleanup
    CGEventTapEnable(tap, false);
    CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
    CFRelease(runLoopSource);
    CFRelease(tap);

    std::cout << "[daemon] Stopped.\n";
    return 0;
}

} // namespace miniwm
