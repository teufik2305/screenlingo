import Foundation
import AppKit
import CryptoKit
import CoreGraphics

/// Result of a window capture operation
struct CaptureResult {
    let image: NSImage
    let bounds: CGRect
    let processID: Int32
    let appName: String
    let screen: NSScreen?  // The screen the window is primarily on (for multi-monitor support)
}

/// Handles window capture and screen recording permissions
class WindowCaptureService {
    private var hasLoggedPermissionError = false
    
    /// Capture the frontmost window
    func captureFrontmost() async -> CaptureResult? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              frontApp.bundleIdentifier != Bundle.main.bundleIdentifier else {
            return nil
        }
        
        let appName = frontApp.localizedName ?? frontApp.bundleIdentifier ?? "Unknown"
        let pid = frontApp.processIdentifier
        
        // Check screen recording permission
        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
            if !hasLoggedPermissionError {
                hasLoggedPermissionError = true
                log.warning("Screen Recording permission required.", category: .engine)
            }
            return nil
        }
        
        // Use CGWindowList for both bounds and image capture
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            // This can happen if:
            // 1. Permission was just granted (needs restart)
            // 2. App was rebuilt and old permission entry is stale
            if !hasLoggedPermissionError {
                hasLoggedPermissionError = true
                log.warning("Screen capture failed - permission may be stale after rebuild", category: .engine)
            }
            return nil
        }
        
        // Extra check: if windowList is empty, permission might be broken
        if windowList.isEmpty && !hasLoggedPermissionError {
            hasLoggedPermissionError = true
            log.warning("No windows found - permission may be stale after rebuild", category: .engine)
            return nil
        }
        
        for window in windowList {
            guard let ownerPID = window[kCGWindowOwnerPID as String] as? Int32,
                  ownerPID == pid,
                  let windowID = window[kCGWindowNumber as String] as? CGWindowID,
                  let boundsDict = window[kCGWindowBounds as String] as? [String: CGFloat],
                  let layer = window[kCGWindowLayer as String] as? Int,
                  layer == 0 else { continue }
            
            let bounds = CGRect(
                x: boundsDict["X"] ?? 0,
                y: boundsDict["Y"] ?? 0,
                width: boundsDict["Width"] ?? 0,
                height: boundsDict["Height"] ?? 0
            )
            
            guard bounds.width > 300, bounds.height > 300 else { continue }
            
            // Capture using CGWindowListCreateImage (deprecated but works correctly)
            guard let cgImage = CGWindowListCreateImage(
                bounds, .optionIncludingWindow, windowID, [.boundsIgnoreFraming]
            ) else { continue }
            
            let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            
            // Detect which screen the window is primarily on
            let windowScreen = findScreenForWindow(bounds: bounds)
            
            return CaptureResult(image: image, bounds: bounds, processID: pid, appName: appName, screen: windowScreen)
        }
        
        return nil
    }
    
    /// Find which screen a window is primarily on based on its bounds
    /// CGWindowList uses screen coordinates where (0,0) is top-left of primary screen
    /// NSScreen uses Cocoa coordinates where (0,0) is bottom-left of primary screen
    private func findScreenForWindow(bounds: CGRect) -> NSScreen? {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return nil }
        
        // Convert CG coordinates (origin top-left) to Cocoa coordinates (origin bottom-left)
        // For the primary screen, we need to flip the Y coordinate
        guard let primaryScreen = screens.first else { return nil }
        let primaryHeight = primaryScreen.frame.height
        
        // Convert window bounds from CG (top-left origin) to Cocoa (bottom-left origin)
        let cocoaBounds = CGRect(
            x: bounds.origin.x,
            y: primaryHeight - bounds.origin.y - bounds.height,
            width: bounds.width,
            height: bounds.height
        )
        
        // Find the screen that contains the center of the window
        let windowCenter = CGPoint(x: cocoaBounds.midX, y: cocoaBounds.midY)
        
        for screen in screens {
            if screen.frame.contains(windowCenter) {
                return screen
            }
        }
        
        // Fallback: find screen with most overlap
        var maxOverlapArea: CGFloat = 0
        var bestScreen: NSScreen? = nil
        
        for screen in screens {
            let intersection = screen.frame.intersection(cocoaBounds)
            if !intersection.isNull {
                let area = intersection.width * intersection.height
                if area > maxOverlapArea {
                    maxOverlapArea = area
                    bestScreen = screen
                }
            }
        }
        
        return bestScreen ?? screens.first
    }
    
    /// Generate a hash of an image for change detection
    func hashImage(_ image: NSImage) -> String {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            return UUID().uuidString
        }
        
        var samples: [UInt8] = []
        let stepX = max(1, bitmap.pixelsWide / 15)
        let stepY = max(1, bitmap.pixelsHigh / 15)
        
        for y in stride(from: 0, to: bitmap.pixelsHigh, by: stepY) {
            for x in stride(from: 0, to: bitmap.pixelsWide, by: stepX) {
                if let color = bitmap.colorAt(x: x, y: y) {
                    samples.append(UInt8(color.redComponent * 255))
                }
            }
        }
        
        let hash = SHA256.hash(data: Data(samples))
        return hash.compactMap { String(format: "%02x", $0) }.joined().prefix(12).description
    }
}
