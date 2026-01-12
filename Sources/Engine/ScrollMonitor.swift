import Foundation
import Cocoa

/// Monitors global scroll events to detect when user is scrolling
class ScrollMonitor {
    static let shared = ScrollMonitor()
    
    private var scrollEventMonitor: Any?
    private var lastScrollTime: Date = .distantPast
    private var scrollEventCount: Int = 0
    private var velocityResetTimer: Timer?
    
    /// Callback when scrolling starts (to clear overlay)
    var onScrollStart: (() -> Void)?
    
    /// Whether monitoring is active
    private(set) var isMonitoring = false
    
    /// Whether user is currently scrolling (within cooldown period)
    var isScrolling: Bool {
        guard isMonitoring else { return false }
        let timeSinceScroll = Date().timeIntervalSince(lastScrollTime)
        return timeSinceScroll < cooldown
    }
    
    /// Cooldown period after scroll stops (seconds)
    var cooldown: TimeInterval = 0.4
    
    /// Scroll events per second threshold to trigger "scrolling" state
    var velocityThreshold: Double = 3.0
    
    private var wasScrolling = false
    
    private init() {}
    
    /// Start monitoring scroll events
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        // Monitor scroll wheel events globally
        scrollEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.scrollWheel]) { [weak self] event in
            self?.handleScrollEvent(event)
        }
        
        // Also monitor local events (when our app is focused)
        // This helps catch events in our own windows
        
        isMonitoring = true
        log.debug("Scroll monitoring started", category: .engine)
    }
    
    /// Stop monitoring scroll events
    func stopMonitoring() {
        if let monitor = scrollEventMonitor {
            NSEvent.removeMonitor(monitor)
            scrollEventMonitor = nil
        }
        velocityResetTimer?.invalidate()
        velocityResetTimer = nil
        isMonitoring = false
        wasScrolling = false
        log.debug("Scroll monitoring stopped", category: .engine)
    }
    
    private func handleScrollEvent(_ event: NSEvent) {
        let now = Date()
        
        // Check if this is a meaningful scroll (not just trackpad noise)
        let scrollMagnitude = abs(event.scrollingDeltaY) + abs(event.scrollingDeltaX)
        guard scrollMagnitude > 0.5 else { return }
        
        // Track velocity
        scrollEventCount += 1
        
        // Reset velocity counter periodically
        velocityResetTimer?.invalidate()
        velocityResetTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.scrollEventCount = 0
        }
        
        // Calculate current velocity
        let timeSinceLastScroll = now.timeIntervalSince(lastScrollTime)
        let velocity = timeSinceLastScroll > 0 ? 1.0 / timeSinceLastScroll : 10.0
        
        lastScrollTime = now
        
        // Trigger scroll start callback if transitioning to scrolling state
        if !wasScrolling && velocity >= velocityThreshold {
            wasScrolling = true
            DispatchQueue.main.async { [weak self] in
                self?.onScrollStart?()
            }
            log.debug("Scroll detected (velocity: \(String(format: "%.1f", velocity))/s)", category: .engine)
        }
        
        // Reset wasScrolling after cooldown
        DispatchQueue.main.asyncAfter(deadline: .now() + cooldown + 0.1) { [weak self] in
            if let self = self, !self.isScrolling {
                self.wasScrolling = false
            }
        }
    }
    
    /// Time remaining until scroll cooldown expires (for logging)
    var cooldownRemaining: TimeInterval {
        let timeSinceScroll = Date().timeIntervalSince(lastScrollTime)
        return max(0, cooldown - timeSinceScroll)
    }
}
