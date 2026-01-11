import SwiftUI
import AppKit
import Combine

@main
struct OverlayTranslatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appDelegate.translatorState)
                .environmentObject(appDelegate)
        } label: {
            MenuBarIcon()
                .environmentObject(appDelegate)
        }
    }
}

/// Menu bar icon using SF Symbols - overlapping squares
struct MenuBarIcon: View {
    @EnvironmentObject var appDelegate: AppDelegate
    
    var body: some View {
        Image(systemName: appDelegate.isTranslating 
              ? "square.filled.on.square" 
              : "square.on.square")
            .id(appDelegate.isTranslating)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let translatorState = TranslatorState()
    var overlayWindow: NSWindow?
    var overlayView: RealTimeOverlayView?
    var translationEngine: RealTimeTranslationEngine?
    private var settingsWindowController: SettingsWindowController?
    private var globalHotkeyMonitor: Any?
    private var accessibilityTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    @Published var isTranslating = false
    @Published var hiddenOverlays: [(original: String, translated: String)] = []
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check and request screen recording permission on startup
        let screenCaptureGranted = CGPreflightScreenCaptureAccess()
        
        if !screenCaptureGranted {
            print("[Permission] Requesting Screen Recording permission...")
            print("             Grant permission in the system dialog, then RESTART the app")
            CGRequestScreenCaptureAccess()
        } else {
            print("[Permission] Screen Recording OK")
        }
        
        // Check and request accessibility (required for global hotkeys)
        // This will show the system prompt if not already granted
        let accessibilityGranted = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        )
        
        if accessibilityGranted {
            print("[Permission] Accessibility OK")
            registerGlobalHotkey()
        } else {
            print("[Permission] Accessibility required for global hotkey (\(translatorState.hotkeyDisplayString))")
            print("             Grant permission in System Settings > Privacy & Security > Accessibility")
            // Start polling - will register hotkey once permission is granted
            startAccessibilityPolling()
            // Show alert after a longer delay - gives user time to interact with system prompt
            // The alert will be skipped if permission is granted in the meantime
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                self?.showAccessibilityAlert()
            }
        }
        
        // Local monitor always works (for when app window is focused)
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            if self.isHotkeyMatch(event) {
                DispatchQueue.main.async {
                    self.toggleTranslation()
                }
            }
            return event
        }
        
        // Listen for clear cache notification from settings
        NotificationCenter.default.addObserver(
            forName: TranslatorState.clearCacheNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.clearTranslationCache()
        }
        
        // Listen for delete cache file notification
        NotificationCenter.default.addObserver(
            forName: TranslatorState.deleteCacheFileNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.deleteCacheFile()
        }
        
        // Listen for save cache notification
        NotificationCenter.default.addObserver(
            forName: TranslatorState.saveCacheNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.saveTranslationCache()
        }
        
        // Save cache on app termination
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.saveTranslationCache()
        }
        
        // Observe alwaysOnTop setting changes to update window level in real-time
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.updateOverlayWindowLevel(alwaysOnTop: self.translatorState.alwaysOnTop)
            }
            .store(in: &cancellables)
        
        print("Overlay Translator started! Press \(translatorState.hotkeyDisplayString) to toggle.")
    }
    
    private func registerGlobalHotkey() {
        // Don't register twice
        guard globalHotkeyMonitor == nil else { return }
        
        globalHotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }
            if self.isHotkeyMatch(event) {
                DispatchQueue.main.async {
                    self.toggleTranslation()
                }
            }
        }
        
        if globalHotkeyMonitor != nil {
            print("[Hotkey] Global hotkey (\(translatorState.hotkeyDisplayString)) registered successfully")
        }
    }
    
    private func isHotkeyMatch(_ event: NSEvent) -> Bool {
        let expectedKeyCode = UInt16(translatorState.hotkeyKeyCode)
        let expectedModifiers = NSEvent.ModifierFlags(rawValue: UInt(translatorState.hotkeyModifiers))
        let relevantModifiers: NSEvent.ModifierFlags = [.command, .control, .option, .shift]
        
        return event.keyCode == expectedKeyCode &&
               event.modifierFlags.intersection(relevantModifiers) == expectedModifiers.intersection(relevantModifiers)
    }
    
    private func startAccessibilityPolling() {
        // Poll every 1 second to check if user granted accessibility
        accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            if AXIsProcessTrusted() {
                print("[Permission] Accessibility granted!")
                timer.invalidate()
                self?.accessibilityTimer = nil
                self?.registerGlobalHotkey()
            }
        }
    }
    
    func toggleTranslation() {
        if isTranslating {
            stopTranslation()
        } else {
            startTranslation()
        }
    }
    
    func startTranslation() {
        guard !isTranslating else { return }
        isTranslating = true
        
        guard let screen = NSScreen.main else { return }
        
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        // Set window level based on user preference
        // .screenSaver (Level 1000) = highest standard level, appears above everything
        // .floating (Level 3) = above normal windows but below alerts/menus
        // Note: Games using exclusive fullscreen (Metal/OpenGL direct rendering) bypass the window compositor
        // and cannot have overlays - user must run game in windowed/borderless mode
        window.level = translatorState.alwaysOnTop ? .screenSaver : .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = true  // Always pass through - use global monitors for interaction
        // Collection behaviors for appearing on all spaces and over fullscreen apps
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        
        let overlayView = RealTimeOverlayView(
            frame: screen.frame,
            translatorState: translatorState,
            onIgnoreText: { [weak self] text in
                self?.translatorState.addIgnoredPattern(text)
                self?.restartTranslationEngine()
            },
            onHiddenChanged: { [weak self] hiddenList in
                self?.hiddenOverlays = hiddenList
            }
        )
        window.contentView = overlayView
        window.orderFrontRegardless()
        
        self.overlayWindow = window
        self.overlayView = overlayView
        
        translationEngine = RealTimeTranslationEngine(
            sourceLanguage: translatorState.sourceLanguage,
            targetLanguage: translatorState.targetLanguage,
            translatorState: translatorState,
            onUpdate: { [weak self] textBlocks in
                DispatchQueue.main.async {
                    self?.overlayView?.updateTextBlocks(textBlocks)
                }
            },
            onClear: { [weak self] in
                DispatchQueue.main.async {
                    self?.overlayView?.clearBlocks()
                }
            },
            onPermissionError: { [weak self] in
                self?.showPermissionAlert()
            }
        )
        translationEngine?.start()
    }
    
    func stopTranslation() {
        isTranslating = false
        translationEngine?.stop()
        translationEngine = nil
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
        overlayView = nil
        hiddenOverlays = []
    }
    
    private func updateOverlayWindowLevel(alwaysOnTop: Bool) {
        guard let window = overlayWindow else { return }
        window.level = alwaysOnTop ? .screenSaver : .floating
    }
    
    func unhideOverlay(_ originalText: String) {
        overlayView?.unhideBlock(originalText)
    }
    
    func unhideAllOverlays() {
        overlayView?.unhideAll()
    }
    
    func clearTranslationCache() {
        translationEngine?.clearCache()
    }
    
    func deleteCacheFile() {
        log.info("Delete cache file button clicked", category: .app)
        
        let path = translatorState.effectiveCacheFilePath
        log.info("Deleting cache file at: \(path)", category: .app)
        
        do {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: path) {
                try FileManager.default.removeItem(at: url)
                log.info("Cache file deleted: \(path)", category: .app)
            } else {
                log.info("No cache file to delete at \(path)", category: .app)
            }
        } catch {
            log.error("Failed to delete cache file: \(error)", category: .app)
        }
    }
    
    func saveTranslationCache() {
        translationEngine?.saveCache()
    }
    
    var cacheSize: Int {
        translationEngine?.cacheSize ?? 0
    }
    
    func restartTranslationEngine() {
        guard isTranslating else { return }
        stopTranslation()
        startTranslation()
    }
    
    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = """
        ScreenLingo needs Screen Recording permission to capture and translate text.
        
        If you see a system dialog, click "Open System Settings" and enable ScreenLingo.
        
        If no dialog appeared (app was rebuilt):
        1. Open System Settings → Privacy & Security → Screen Recording
        2. Remove ScreenLingo from the list (click -)
        3. Quit and restart this app
        4. Grant permission when prompted
        
        Note: With a signed release build, you won't need to do this after updates.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Later")
        
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
        
        NSApp.setActivationPolicy(.accessory)
    }
    
    private func showAccessibilityAlert() {
        // Skip if accessibility was granted in the meantime
        guard !AXIsProcessTrusted() else { return }
        
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = """
        ScreenLingo needs Accessibility permission for the global keyboard shortcut (Cmd+Ctrl+T).
        
        Please grant permission in System Settings:
        1. Click "Open Settings" below
        2. Find ScreenLingo and toggle it ON
        3. The shortcut will work immediately (no restart needed)
        
        If ScreenLingo isn't listed or the shortcut doesn't work:
        1. Remove ScreenLingo from the list (click -)
        2. Quit and restart this app
        3. Grant permission when prompted
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Later")
        
        // Must become a regular app to show alerts properly
        NSApp.setActivationPolicy(.regular)
        
        // Force the app to come to front
        NSApp.activate(ignoringOtherApps: true)
        
        // Small delay to ensure activation takes effect
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Open Accessibility settings directly
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
        
        NSApp.setActivationPolicy(.accessory)
    }
    
    func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(state: translatorState)
        }
        settingsWindowController?.showWindow()
    }
}

// Dedicated settings window controller
class SettingsWindowController {
    private var window: NSWindow?
    private let state: TranslatorState
    
    init(state: TranslatorState) {
        self.state = state
    }
    
    func showWindow() {
        if window == nil {
            let settingsView = SettingsView(state: state)
            let hostingController = NSHostingController(rootView: settingsView)
            
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Settings"
            window.styleMask = [.titled, .closable]
            window.level = .normal
            window.center()
            window.isReleasedWhenClosed = false
            window.setFrameAutosaveName("SettingsWindow")
            
            // Watch for window close to go back to accessory mode
            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: window,
                queue: .main
            ) { _ in
                NSApp.setActivationPolicy(.accessory)
            }
            
            self.window = window
        }
        
        // Become regular app so window stays visible
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
