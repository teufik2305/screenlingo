import SwiftUI

struct IgnoreListEditor: View {
    @ObservedObject var state: TranslatorState
    @State private var newPattern = ""
    
    var body: some View {
        VStack(spacing: 8) {
            // Add new pattern
            HStack {
                TextField("Add pattern...", text: $newPattern)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addPattern() }
                
                Button("Add") { addPattern() }
                    .disabled(newPattern.isEmpty)
            }
            
            // Pattern list
            if state.ignorePatternManager.ignoredPatterns.isEmpty {
                Text("No patterns")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .padding(.vertical, 4)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(state.ignorePatternManager.ignoredPatterns, id: \.self) { pattern in
                        PatternTag(pattern: pattern) {
                            state.ignorePatternManager.removeIgnoredPattern(pattern)
                        }
                    }
                }
            }
        }
    }
    
    private func addPattern() {
        let trimmed = newPattern.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            state.ignorePatternManager.addIgnoredPattern(trimmed)
            newPattern = ""
        }
    }
}
