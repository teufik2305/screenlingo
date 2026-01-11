import SwiftUI

struct StatsView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Session Statistics")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding()
            
            Divider()
            
            // Stats content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    StatRow(label: "Session Duration", value: sessionDuration)
                    StatRow(label: "Total Translations", value: "\(log.stats.totalTranslations)")
                    
                    Divider()
                    
                    StatRow(label: "Cache Hits", value: "\(log.stats.cacheHits)")
                    StatRow(label: "API Calls", value: "\(log.stats.apiCalls)")
                    StatRow(label: "Apple Translation", value: "\(log.stats.appleTranslationCalls)")
                    StatRow(label: "LTEngine Calls", value: "\(log.stats.libreTranslateCalls)")
                    StatRow(label: "LLM Calls", value: "\(log.stats.llmCalls)")
                    StatRow(label: "Cache Hit Rate", value: String(format: "%.1f%%", log.stats.cacheHitRate))
                    
                    Divider()
                    
                    StatRow(label: "Avg API Time", value: String(format: "%.0fms", log.stats.averageApiTime * 1000))
                    StatRow(label: "Characters Translated", value: "\(log.stats.totalCharacters)")
                    StatRow(label: "Errors", value: "\(log.stats.errors)")
                }
                .padding()
            }
            
            Divider()
            
            // Footer
            HStack {
                Button("Reset Statistics") {
                    log.stats.reset()
                }
                .foregroundStyle(.red)
                
                Spacer()
                
                Button("Copy to Clipboard") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(log.stats.summary(), forType: .string)
                }
            }
            .padding()
        }
        .frame(width: 350, height: 400)
    }
    
    var sessionDuration: String {
        let duration = Date().timeIntervalSince(log.stats.sessionStart)
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        return "\(minutes)m \(seconds)s"
    }
}
