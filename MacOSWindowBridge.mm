#include "MacOSWindowBridge.h"
#include <AppKit/AppKit.h>
#include <iostream>

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

// Helper: copy CFStringRef to std::string
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
    char buffer[256];
    bool success = CFStringGetCString(strRef, buffer, sizeof(buffer), kCFStringEncodingUTF8);
    if (success) out = buffer;
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

    // 3. Check valid bounds
    AXValueRef positionRef, sizeRef;
    CGPoint position;
    CGSize size;
    bool hasBounds = true;
    if (AXUIElementCopyAttributeValue(windowRef, kAXPositionAttribute, (CFTypeRef*)&positionRef) == kAXErrorSuccess) {
        AXValueGetValue(positionRef, (AXValueType)kAXValueCGPointType, &position);
        CFRelease(positionRef);
    } else {
        hasBounds = false;
    }
    if (AXUIElementCopyAttributeValue(windowRef, kAXSizeAttribute, (CFTypeRef*)&sizeRef) == kAXErrorSuccess) {
        AXValueGetValue(sizeRef, (AXValueType)kAXValueCGSizeType, &size);
        CFRelease(sizeRef);
    } else {
        hasBounds = false;
    }
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

} // namespace miniwm
