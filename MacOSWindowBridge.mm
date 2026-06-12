#include "MacOSWindowBridge.h"
#include <AppKit/AppKit.h>
#include <cmath>
#include <iostream>
#include <unistd.h>
#include <vector>

namespace miniwm {

ManagedWindow::ManagedWindow(AXUIElementRef ref, const WindowInfo& info)
    : ref_(ref), info_(info) {}

ManagedWindow::~ManagedWindow() {
    if (ref_) CFRelease(ref_);
}

ManagedWindow::ManagedWindow(ManagedWindow&& other) noexcept
    : ref_(other.ref_), info_(other.info_) {
    other.ref_ = nullptr;
}

ManagedWindow& ManagedWindow::operator=(ManagedWindow&& other) noexcept {
    if (this != &other) {
        if (ref_) CFRelease(ref_);
        ref_ = other.ref_;
        info_ = other.info_;
        other.ref_ = nullptr;
    }
    return *this;
}

const WindowInfo& ManagedWindow::info() const {
    return info_;
}

bool ManagedWindow::setPositionAndSize(int x, int y, int w, int h) const {
    CGPoint position = CGPointMake(x, y);
    CGSize size = CGSizeMake(w, h);

    AXValueRef positionRef = AXValueCreate((AXValueType)kAXValueCGPointType, &position);
    AXValueRef sizeRef = AXValueCreate((AXValueType)kAXValueCGSizeType, &size);

    if (!positionRef || !sizeRef) {
        if (positionRef) CFRelease(positionRef);
        if (sizeRef) CFRelease(sizeRef);
        return false;
    }

    AXError posErr = AXUIElementSetAttributeValue(ref_, kAXPositionAttribute, positionRef);
    AXError sizeErr = AXUIElementSetAttributeValue(ref_, kAXSizeAttribute, sizeRef);

    CFRelease(positionRef);
    CFRelease(sizeRef);

    return posErr == kAXErrorSuccess && sizeErr == kAXErrorSuccess;
}

AXUIElementRef ManagedWindow::nativeRef() const {
    return ref_;
}

// Helper: check if two rects overlap (with a small epsilon tolerance for edges)
static bool rectsOverlap(CGRect a, CGRect b) {
    const double epsilon = 1.0;
    return (a.origin.x + a.size.width > b.origin.x + epsilon)
        && (b.origin.x + b.size.width > a.origin.x + epsilon)
        && (a.origin.y + a.size.height > b.origin.y + epsilon)
        && (b.origin.y + b.size.height > a.origin.y + epsilon);
}

// Helper: cross-check AX window against CGWindowList.
// Matches by same PID and overlapping bounds (loose match — any visible overlap).
static bool isAXWindowOnScreen(AXUIElementRef windowRef, pid_t pid) {
    // Get AX position and size
    AXValueRef positionRef = NULL, sizeRef = NULL;
    CGPoint position = {0, 0};
    CGSize size = {0, 0};

    bool gotPos = AXUIElementCopyAttributeValue(windowRef, kAXPositionAttribute, (CFTypeRef*)&positionRef) == kAXErrorSuccess
                  && positionRef
                  && CFGetTypeID(positionRef) == AXValueGetTypeID()
                  && AXValueGetValue(positionRef, (AXValueType)kAXValueCGPointType, &position);
    if (positionRef) CFRelease(positionRef);

    bool gotSize = AXUIElementCopyAttributeValue(windowRef, kAXSizeAttribute, (CFTypeRef*)&sizeRef) == kAXErrorSuccess
                  && sizeRef
                  && CFGetTypeID(sizeRef) == AXValueGetTypeID()
                  && AXValueGetValue(sizeRef, (AXValueType)kAXValueCGSizeType, &size);
    if (sizeRef) CFRelease(sizeRef);

    if (!gotPos || !gotSize) return true; // Can't verify, assume visible

    CGRect axBounds = CGRectMake(position.x, position.y, size.width, size.height);

    // Query CGWindowList for on-screen windows
    CFArrayRef windowList = CGWindowListCopyWindowInfo(
        kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements,
        kCGNullWindowID
    );
    if (!windowList) return true;

    bool found = false;
    for (CFIndex i = 0; i < CFArrayGetCount(windowList); i++) {
        CFDictionaryRef info = (CFDictionaryRef)CFArrayGetValueAtIndex(windowList, i);
        CFNumberRef pidRef = (CFNumberRef)CFDictionaryGetValue(info, kCGWindowOwnerPID);
        CFDictionaryRef boundsRef = (CFDictionaryRef)CFDictionaryGetValue(info, kCGWindowBounds);
        if (!pidRef || !boundsRef) continue;

        pid_t infoPid;
        if (!CFNumberGetValue(pidRef, kCFNumberIntType, &infoPid)) continue;
        if (infoPid != pid) continue;

        // Compare bounds — loose match: same PID with overlapping bounds
        CGRect cgBounds;
        if (CGRectMakeWithDictionaryRepresentation(boundsRef, &cgBounds)) {
            if (rectsOverlap(axBounds, cgBounds)) {
                found = true;
                break;
            }
        }
    }

    CFRelease(windowList);
    return found;
}

// Helper: copy CFStringRef to std::string
// Uses dynamic buffer size to handle titles of any length.
static bool getStringAttribute(AXUIElementRef element, CFStringRef attr, std::string& out) {
    CFTypeRef ref;
    if (AXUIElementCopyAttributeValue(element, attr, &ref) != kAXErrorSuccess) {
        return false;
    }
    if (CFGetTypeID(ref) != CFStringGetTypeID()) {
        CFRelease(ref);
        return false;
    }
    CFStringRef strRef = (CFStringRef)ref;

    // Get the maximum buffer size needed for this string in UTF-8 encoding
    CFIndex length = CFStringGetLength(strRef);
    CFIndex maxSize = CFStringGetMaximumSizeForEncoding(length, kCFStringEncodingUTF8) + 1;

    // Cap at a reasonable limit to avoid pathological allocations
    const CFIndex kMaxTitleSize = 64 * 1024; // 64KB
    if (maxSize > kMaxTitleSize) maxSize = kMaxTitleSize;

    std::vector<char> buffer(maxSize);
    bool success = CFStringGetCString(strRef, buffer.data(), buffer.size(), kCFStringEncodingUTF8);
    if (success) {
        out.assign(buffer.data());
    }
    CFRelease(strRef);
    return success;
}

// Fetch window info and apply filtering
static bool fetchWindowInfo(AXUIElementRef windowRef, WindowInfo& info, bool strict) {
    // 1. Check role == kAXWindowRole
    CFStringRef roleRef;
    if (AXUIElementCopyAttributeValue(windowRef, kAXRoleAttribute, (CFTypeRef*)&roleRef) != kAXErrorSuccess) {
        return false;
    }
    bool isWindow = CFStringCompare(roleRef, kAXWindowRole, 0) == kCFCompareEqualTo;
    CFRelease(roleRef);
    if (!isWindow) return false;

    // 2. Check not minimized
    CFBooleanRef minimizedRef;
    bool minimized = false;
    if (AXUIElementCopyAttributeValue(windowRef, kAXMinimizedAttribute, (CFTypeRef*)&minimizedRef) == kAXErrorSuccess) {
        minimized = CFBooleanGetValue(minimizedRef);
        CFRelease(minimizedRef);
    }
    if (minimized) return false;

    // 3. Check valid bounds (validate type ID and extraction success)
    AXValueRef positionRef = NULL;
    AXValueRef sizeRef = NULL;
    CGPoint position = {0, 0};
    CGSize size = {0, 0};
    bool hasBounds = false;

    if (AXUIElementCopyAttributeValue(windowRef, kAXPositionAttribute, (CFTypeRef*)&positionRef) == kAXErrorSuccess
        && positionRef
        && CFGetTypeID(positionRef) == AXValueGetTypeID()
        && AXValueGetValue(positionRef, (AXValueType)kAXValueCGPointType, &position)) {
        hasBounds = true;
    }
    if (positionRef) CFRelease(positionRef);
    positionRef = NULL;

    if (AXUIElementCopyAttributeValue(windowRef, kAXSizeAttribute, (CFTypeRef*)&sizeRef) == kAXErrorSuccess
        && sizeRef
        && CFGetTypeID(sizeRef) == AXValueGetTypeID()
        && AXValueGetValue(sizeRef, (AXValueType)kAXValueCGSizeType, &size)) {
        // keep hasBounds as true only if both succeeded
    } else {
        hasBounds = false;
    }
    if (sizeRef) CFRelease(sizeRef);
    sizeRef = NULL;

    if (!hasBounds || size.width <= 0 || size.height <= 0) return false;

    // 4. Strict filtering
    if (strict) {
        std::string subrole;
        if (getStringAttribute(windowRef, kAXSubroleAttribute, subrole)) {
            if (subrole != "AXStandardWindow") return false;
        }
        if (size.width < 50 || size.height < 50) return false;
    }

    // 5. Extract info
    std::string title;
    getStringAttribute(windowRef, kAXTitleAttribute, title);

    info.x = (int)position.x;
    info.y = (int)position.y;
    info.w = (int)size.width;
    info.h = (int)size.height;
    info.title = title;

    return true;
}

static std::vector<ManagedWindow> enumerateWindowsInternal(bool strict) {
    std::vector<ManagedWindow> result;
    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    NSArray<NSRunningApplication *> *apps = [workspace runningApplications];

    // Get our own PID so we skip ourselves
    pid_t selfPid = getpid();

    for (NSRunningApplication *app in apps) {
        pid_t pid = app.processIdentifier;
        if (pid == 0 || pid == selfPid) continue;

        // Skip hidden apps
        if (app.isHidden) continue;

        // Skip non-regular apps (optional but recommended for MVP)
        if (app.activationPolicy != NSApplicationActivationPolicyRegular) continue;

        // Create AXUIElement for this application
        AXUIElementRef appRef = AXUIElementCreateApplication(pid);
        if (!appRef) continue;

        // Get windows list for this application
        CFArrayRef windowList;
        AXError error = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute, (CFTypeRef*)&windowList);
        if (error != kAXErrorSuccess || !windowList) {
            CFRelease(appRef);
            continue;
        }

        for (NSInteger i = 0; i < CFArrayGetCount(windowList); i++) {
            AXUIElementRef windowRef = (AXUIElementRef)CFArrayGetValueAtIndex(windowList, i);

            WindowInfo info;
            if (!fetchWindowInfo(windowRef, info, strict)) continue;

            // Cross-check against CGWindowList to ensure window is actually
            // on-screen on the current Space/display.
            if (!isAXWindowOnScreen(windowRef, pid)) continue;

            // We take ownership of this window ref
            CFRetain(windowRef);

            // Get app name
            std::string appName;
            const char* name = [[app localizedName] UTF8String];
            if (name) appName = name;

            info.pid = pid;
            info.appName = appName;

            result.emplace_back(windowRef, info);
        }

        CFRelease(windowList);
        CFRelease(appRef);
    }

    return result;
}

bool checkAccessibilityPermission() {
    // Ask macOS to show the permission prompt if not already trusted
    NSDictionary *options = @{(__bridge NSString *)kAXTrustedCheckOptionPrompt: @YES};
    return AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
}

std::vector<ManagedWindow> enumerateWindows() {
    // Try strict filtering first
    auto strict = enumerateWindowsInternal(true);
    if (!strict.empty()) return strict;

    // Fallback to relaxed filtering
    return enumerateWindowsInternal(false);
}

Rect getMainScreenVisibleFrame() {
    // Use NSScreen.visibleFrame to get the usable area excluding the menu
    // bar and Dock. NSScreen returns coordinates in Cocoa space (bottom-left
    // origin). We convert to screen coordinates (top-left origin) for use
    // with the AX-based layout code.
    NSScreen *mainScreen = [NSScreen mainScreen];
    if (!mainScreen) {
        // Fallback to CGDisplayBounds if NSScreen is unavailable
        CGRect bounds = CGDisplayBounds(CGMainDisplayID());
        return Rect{
            (int)bounds.origin.x,
            (int)bounds.origin.y,
            (int)bounds.size.width,
            (int)bounds.size.height
        };
    }

    NSRect visible = [mainScreen visibleFrame];
    NSRect full = [mainScreen frame];

    // Convert from Cocoa (bottom-left) to screen (top-left) coordinates.
    // screenHeight = full.size.height
    // y_top = screenHeight - y_bottom - height
    int screenHeight = (int)full.size.height;
    int x = (int)visible.origin.x;
    int y = screenHeight - (int)visible.origin.y - (int)visible.size.height;
    int w = (int)visible.size.width;
    int h = (int)visible.size.height;

    return Rect{x, y, w, h};
}

bool windowIntersectsScreen(const WindowInfo& window, const Rect& screen) {
    // Both `window` (from AX) and `screen` (converted from NSScreen) are
    // in screen coordinates with top-left origin. CGRectIntersectsRect
    // works correctly when both rects are in the same coordinate space.
    CGRect screenRect = CGRectMake(screen.x, screen.y, screen.w, screen.h);
    CGRect windowRect = CGRectMake(window.x, window.y, window.w, window.h);
    return CGRectIntersectsRect(screenRect, windowRect);
}

WindowInfo getFocusedWindow() {
    WindowInfo result;
    result.pid = 0;

    AXUIElementRef systemWide = AXUIElementCreateSystemWide();
    if (!systemWide) return result;

    AXUIElementRef frontApp = nullptr;
    if (AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute, (CFTypeRef*)&frontApp) != kAXErrorSuccess || !frontApp) {
        CFRelease(systemWide);
        return result;
    }

    pid_t pid = 0;
    AXUIElementGetPid(frontApp, &pid);

    AXUIElementRef focusedWindow = nullptr;
    if (AXUIElementCopyAttributeValue(frontApp, kAXFocusedWindowAttribute, (CFTypeRef*)&focusedWindow) != kAXErrorSuccess || !focusedWindow) {
        CFRelease(frontApp);
        CFRelease(systemWide);
        return result;
    }

    // Read the window info using the existing fetchWindowInfo helper
    WindowInfo info;
    if (fetchWindowInfo(focusedWindow, info, false)) {
        info.pid = pid;
        result = info;
    }

    CFRelease(focusedWindow);
    CFRelease(frontApp);
    CFRelease(systemWide);
    return result;
}

bool focusWindow(AXUIElementRef windowRef) {
    if (!windowRef) return false;
    AXError err = AXUIElementSetAttributeValue(windowRef, kAXMainAttribute, kCFBooleanTrue);
    if (err != kAXErrorSuccess) {
        err = AXUIElementPerformAction(windowRef, kAXRaiseAction);
    }
    return err == kAXErrorSuccess;
}

bool moveWindowBy(AXUIElementRef windowRef, int dx, int dy) {
    if (!windowRef) return false;

    AXValueRef positionRef = nullptr;
    CGPoint position;
    if (AXUIElementCopyAttributeValue(windowRef, kAXPositionAttribute, (CFTypeRef*)&positionRef) != kAXErrorSuccess || !positionRef) {
        return false;
    }
    AXValueGetValue(positionRef, (AXValueType)kAXValueCGPointType, &position);
    CFRelease(positionRef);

    position.x += dx;
    position.y += dy;

    AXValueRef newPositionRef = AXValueCreate((AXValueType)kAXValueCGPointType, &position);
    if (!newPositionRef) return false;

    AXError err = AXUIElementSetAttributeValue(windowRef, kAXPositionAttribute, newPositionRef);
    CFRelease(newPositionRef);
    return err == kAXErrorSuccess;
}

} // namespace miniwm
