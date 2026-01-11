import SwiftUI
import Translation

@available(macOS 26.0, *)
struct AppleTranslationSettings: View {
    @ObservedObject var state: TranslatorState
    @State private var isDownloading = false
    @State private var statusMessage: String = ""
    @State private var configuration: TranslationSession.Configuration?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button(action: downloadLanguagePack) {
                    HStack(spacing: 6) {
                        if isDownloading {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "arrow.down.circle")
                        }
                        Text(isDownloading ? "Downloading..." : "Download Language Packs")
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)
                .disabled(isDownloading)
                
                // Show check button when download is in progress in background
                if statusMessage.contains("↓") {
                    Button("Check") {
                        checkStatus()
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
                
                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(
                            statusMessage.contains("✓") ? .green : 
                            statusMessage.contains("✗") ? .red : 
                            statusMessage.contains("↓") ? .blue : .secondary
                        )
                }
            }
            
            Text("\(state.languageName(for: state.sourceLanguage)) → \(state.languageName(for: state.targetLanguage))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .onAppear { setupConfiguration() }
        .onChange(of: state.sourceLanguage) { _, _ in setupConfiguration() }
        .onChange(of: state.targetLanguage) { _, _ in setupConfiguration() }
        .translationTask(configuration) { session in
            // Perform a test translation to trigger download if needed
            guard isDownloading else { return }
            do {
                _ = try await session.translate("test")
                await MainActor.run {
                    statusMessage = "✓ Ready"
                    isDownloading = false
                }
            } catch {
                await MainActor.run {
                    // Check if it was cancelled (user clicked Done) - download continues in background
                    let errorDesc = error.localizedDescription.lowercased()
                    if errorDesc.contains("cancel") {
                        statusMessage = "↓ Downloading in background..."
                    } else {
                        statusMessage = "✗ \(error.localizedDescription)"
                    }
                    isDownloading = false
                }
            }
        }
    }
    
    private func setupConfiguration() {
        let source = Locale.Language(identifier: state.sourceLanguage)
        let target = Locale.Language(identifier: state.targetLanguage)
        configuration = TranslationSession.Configuration(source: source, target: target)
        statusMessage = ""
    }
    
    private func downloadLanguagePack() {
        isDownloading = true
        statusMessage = ""
        
        Task {
            let source = Locale.Language(identifier: state.sourceLanguage)
            let target = Locale.Language(identifier: state.targetLanguage)
            
            let availability = LanguageAvailability()
            let status = await availability.status(from: source, to: target)
            
            await MainActor.run {
                switch status {
                case .installed:
                    statusMessage = "✓ Ready"
                    isDownloading = false
                case .supported:
                    // Trigger download by invalidating - translationTask will handle it
                    statusMessage = "Starting download..."
                    configuration?.invalidate()
                case .unsupported:
                    statusMessage = "✗ Not supported"
                    isDownloading = false
                @unknown default:
                    statusMessage = "✗ Unknown"
                    isDownloading = false
                }
            }
        }
    }
    
    private func checkStatus() {
        Task {
            let source = Locale.Language(identifier: state.sourceLanguage)
            let target = Locale.Language(identifier: state.targetLanguage)
            
            let availability = LanguageAvailability()
            let status = await availability.status(from: source, to: target)
            
            await MainActor.run {
                switch status {
                case .installed:
                    statusMessage = "✓ Ready"
                case .supported:
                    statusMessage = "↓ Still downloading..."
                case .unsupported:
                    statusMessage = "✗ Not supported"
                @unknown default:
                    statusMessage = "?"
                }
            }
        }
    }
}
