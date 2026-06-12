cmake_minimum_required(VERSION 3.16)
project(miniwm LANGUAGES CXX OBJCXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(miniwm
    main.mm
    Window.cpp
    LayoutEngine.cpp
    MacOSWindowBridge.mm
)

target_link_libraries(miniwm
    "-framework Cocoa"
    "-framework ApplicationServices"
)
