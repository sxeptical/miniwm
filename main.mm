#include "Commands.h"
#include "Config.h"
#include "HotkeyDaemon.h"
#include <cstdlib>
#include <iostream>
#include <string>

struct CommandOptions {
    bool dryRun = false;
};

void printUsage(const char* programName) {
    std::cerr << "Usage:\n"
              << "  " << programName << " list\n"
              << "  " << programName << " tile [--dry-run]\n"
              << "  " << programName << " config-test\n"
              << "  " << programName << " daemon\n"
              << "\n"
              << "Commands:\n"
              << "  list         List visible windows.\n"
              << "  tile         Tile visible windows on the main screen.\n"
              << "  config-test  Print parsed config.\n"
              << "  daemon       Run the hotkey daemon.\n"
              << "\n"
              << "Options:\n"
              << "  --dry-run    For 'tile': print intended positions without applying.\n";
}

bool parseOptions(const std::string& cmd, int argc, char* argv[], int startIndex, CommandOptions& opts, std::string& error) {
    for (int i = startIndex; i < argc; i++) {
        std::string arg = argv[i];
        if (arg == "--dry-run") {
            if (cmd != "tile") {
                error = "--dry-run is only valid with 'tile'";
                return false;
            }
            opts.dryRun = true;
        } else {
            error = "Unknown option: " + arg;
            return false;
        }
    }
    return true;
}

int main(int argc, char* argv[]) {
    if (argc < 2) {
        printUsage(argv[0]);
        return 1;
    }

    std::string cmd = argv[1];

    if (cmd != "list" && cmd != "tile" && cmd != "config-test" && cmd != "daemon") {
        std::cerr << "Unknown command: " << cmd << "\n";
        printUsage(argv[0]);
        return 1;
    }

    CommandOptions opts;
    std::string error;
    if (!parseOptions(cmd, argc, argv, 2, opts, error)) {
        std::cerr << "Error: " << error << "\n";
        printUsage(argv[0]);
        return 1;
    }

    auto config = miniwm::loadConfig();

    if (cmd == "list") {
        return miniwm::cmdList();
    } else if (cmd == "tile") {
        return miniwm::cmdTile(config, opts.dryRun);
    } else if (cmd == "config-test") {
        return miniwm::cmdConfigTest(config);
    } else {
        return miniwm::runDaemon(config);
    }
}
