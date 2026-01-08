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
            
            // Translation service selector
            Menu {
                ForEach(TranslationServiceType.allCases, id: \.rawValue) { service in
                    Button(action: { state.translationService = service }) {
                        HStack {
                            Image(systemName: service.icon)
                            Text(service.name)
                            if state.translationService == service {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .disabled(service == .apple && !TranslationService.isAppleTranslationAvailable)
                }
            } label: {
                HStack {
                    Image(systemName: state.translationService.icon)
                        .foregroundStyle(state.translationService.color)
                        .frame(width: 16)
                    Text(state.translationService.name)
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
            
            // Language row with swap button
            HStack(spacing: 8) {
                // Source language menu
                Menu {
                    ForEach(state.availableSourceLanguages, id: \.code) { lang in
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
                    Text(state.languageName(for: state.sourceLanguage))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .disabled(appDelegate.isTranslating)
                
                // Swap button
                Button(action: { state.swapLanguages() }) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.caption)
                        .foregroundStyle(state.sourceLanguage == "auto" ? .tertiary : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(appDelegate.isTranslating || state.sourceLanguage == "auto")
                
                // Target language menu
                Menu {
                    ForEach(state.availableLanguages, id: \.code) { lang in
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
                    Text(state.languageName(for: state.targetLanguage))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .disabled(appDelegate.isTranslating)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            
            Divider()
            
            // Interaction mode selector
            Menu {
                ForEach(InteractionMode.allCases, id: \.rawValue) { mode in
                    Button(action: { state.interactionMode = mode }) {
                        HStack {
                            Image(systemName: mode.icon)
                            Text(mode.name)
                            if state.interactionMode == mode {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Image(systemName: state.interactionMode.icon)
                        .foregroundStyle(state.interactionMode.color)
                        .frame(width: 16)
                    Text(state.interactionMode.name)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            
            // Hidden overlays section - only show when translating and has hidden items
            if appDelegate.isTranslating && !appDelegate.hiddenOverlays.isEmpty {
                Divider()
                
                Menu {
                    ForEach(appDelegate.hiddenOverlays.indices, id: \.self) { index in
                        let item = appDelegate.hiddenOverlays[index]
                        Button(action: { appDelegate.unhideOverlay(item.original) }) {
                            let preview = item.translated.count > 30 
                                ? String(item.translated.prefix(30)) + "..." 
                                : item.translated
                            Text(preview)
                        }
                    }
                    
                    Divider()
                    
                    Button(action: { appDelegate.unhideAllOverlays() }) {
                        Text("Unhide All")
                    }
                } label: {
                    HStack {
                        Text("Hidden (\(appDelegate.hiddenOverlays.count))")
                        Spacer()
                        Image(systemName: "eye.slash")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            
            Divider()
            
            // Clear Cache
            Button(action: { appDelegate.clearTranslationCache() }) {
                HStack {
                    Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                    Text("Clear Cache")
                    Spacer()
                    if appDelegate.cacheSize > 0 {
                        Text("\(appDelegate.cacheSize)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .disabled(!appDelegate.isTranslating)
            
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
