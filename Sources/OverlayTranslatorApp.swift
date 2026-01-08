import SwiftUI
import AppKit

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
    
    @Published var isTranslating = false
    @Published var hiddenOverlays: [(original: String, translated: String)] = []
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check and request screen recording permission on startup
        let screenCaptureGranted = CGPreflightScreenCaptureAccess()
        
        if !screenCaptureGranted {
            print("[Permission] Requesting Screen Recording permission...")
            print("             Grant permission in the system dialog, then RESTART the app")
            // This shows the system dialog or opens System Settings
            // Don't show our custom alert here - let the engine detect if capture actually fails
            CGRequestScreenCaptureAccess()
        } else {
            print("[Permission] Screen Recording OK")
        }
        
        // Check accessibility (for global hotkeys)
        if !AXIsProcessTrusted() {
            print("[Permission] Accessibility recommended for global hotkey (Cmd+Ctrl+T)")
        }
        
        // Register global hotkey for toggle (Cmd+Control+T)
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains([.command, .control]) && event.keyCode == 17 {
                DispatchQueue.main.async {
                    self?.toggleTranslation()
                }
            }
        }
        
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains([.command, .control]) && event.keyCode == 17 {
                DispatchQueue.main.async {
                    self?.toggleTranslation()
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
        
        print("Overlay Translator started! Press Cmd+Ctrl+T to toggle.")
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
        
        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = true  // Always pass through - use global monitors for interaction
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        
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
    
    func unhideOverlay(_ originalText: String) {
        overlayView?.unhideBlock(originalText)
    }
    
    func unhideAllOverlays() {
        overlayView?.unhideAll()
    }
    
    func clearTranslationCache() {
        translationEngine?.clearCache()
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
            // Open Screen Recording settings directly
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
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
