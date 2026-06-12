cmake_minimum_required(VERSION 3.16)
project(miniwm LANGUAGES CXX OBJCXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(miniwm
    main.mm
    Window.cpp
    LayoutEngine.cpp
    Config.cpp
    Commands.cpp
    MacOSWindowBridge.mm
    HotkeyDaemon.mm
)

target_link_libraries(miniwm
    "-framework Cocoa"
    "-framework ApplicationServices"
)
