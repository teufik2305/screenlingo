import SwiftUI

struct HotkeyRecorderView: NSViewRepresentable {
    @Binding var isRecording: Bool
    @Binding var keyCode: Int
    @Binding var modifiers: Int
    
    func makeNSView(context: Context) -> NSView {
        let view = HotkeyRecorderNSView()
        view.coordinator = context.coordinator
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? HotkeyRecorderNSView else { return }
        if isRecording && !view.isListening {
            view.startListening()
        } else if !isRecording && view.isListening {
            view.stopListening()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator {
        var parent: HotkeyRecorderView
        
        init(_ parent: HotkeyRecorderView) {
            self.parent = parent
        }
        
        func recordKey(keyCode: Int, modifiers: Int) {
            parent.keyCode = keyCode
            parent.modifiers = modifiers
            parent.isRecording = false
        }
    }
}

class HotkeyRecorderNSView: NSView {
    var coordinator: HotkeyRecorderView.Coordinator?
    var isListening = false
    private var localMonitor: Any?
    
    func startListening() {
        isListening = true
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            // Require at least one modifier
            let mods = event.modifierFlags.intersection([.command, .control, .option, .shift])
            if !mods.isEmpty {
                self.coordinator?.recordKey(
                    keyCode: Int(event.keyCode),
                    modifiers: Int(mods.rawValue)
                )
                return nil  // Consume the event
            }
            return event
        }
    }
    
    func stopListening() {
        isListening = false
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
    
    override func removeFromSuperview() {
        stopListening()
        super.removeFromSuperview()
    }
}
