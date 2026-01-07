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
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request accessibility permissions
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
        
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
        
        print("🌍 Overlay Translator started! Press ⌘⌃T to toggle.")
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
    }
    
    func restartTranslationEngine() {
        guard isTranslating else { return }
        stopTranslation()
        startTranslation()
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
