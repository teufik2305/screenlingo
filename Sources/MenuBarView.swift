import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var state: TranslatorState
    @EnvironmentObject var appDelegate: AppDelegate
    
    var body: some View {
        VStack(spacing: 0) {
            // Main toggle button
            Button(action: { appDelegate.toggleTranslation() }) {
                HStack {
                    Circle()
                        .fill(appDelegate.isTranslating ? Color.green : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                    
                    Text(appDelegate.isTranslating ? "Stop" : "Start")
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("⌘⌃T")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            
            Divider()
            
            // Source language menu
            Menu {
                ForEach(TranslatorState.supportedLanguages, id: \.code) { lang in
                    Button(action: { state.sourceLanguage = lang.code }) {
                        HStack {
                            Text(lang.name)
                            if state.sourceLanguage == lang.code {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text("From: \(state.languageName(for: state.sourceLanguage))")
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(appDelegate.isTranslating)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            
            // Target language menu
            Menu {
                ForEach(TranslatorState.supportedLanguages, id: \.code) { lang in
                    Button(action: { state.targetLanguage = lang.code }) {
                        HStack {
                            Text(lang.name)
                            if state.targetLanguage == lang.code {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text("To: \(state.languageName(for: state.targetLanguage))")
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(appDelegate.isTranslating)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            
            Divider()
            
            // Settings
            Button(action: { appDelegate.openSettings() }) {
                HStack {
                    Text("Settings...")
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            
            Divider()
            
            // Quit
            Button(action: { NSApplication.shared.terminate(nil) }) {
                HStack {
                    Text("Quit")
                    Spacer()
                    Text("⌘Q")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .keyboardShortcut("q", modifiers: .command)
        }
        .frame(width: 220)
    }
}
