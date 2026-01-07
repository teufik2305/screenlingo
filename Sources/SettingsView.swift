import SwiftUI

struct SettingsView: View {
    @ObservedObject var state: TranslatorState
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Behavior
                    settingsSection("Interaction Mode") {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle(isOn: $state.hideOnHover) {
                                Text("Auto-hide on hover")
                            }
                            
                            // Visual explanation
                            HStack(spacing: 12) {
                                Image(systemName: state.hideOnHover ? "eye.slash" : "hand.tap")
                                    .font(.title2)
                                    .foregroundStyle(state.hideOnHover ? .orange : .blue)
                                    .frame(width: 30)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(state.hideOnHover ? "Hover Mode" : "Click Mode")
                                        .fontWeight(.medium)
                                    Text(state.hideOnHover 
                                         ? "Move mouse over overlay → it disappears" 
                                         : "Click overlay → menu appears (copy, hide, ignore)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(10)
                            .background(Color(nsColor: .windowBackgroundColor))
                            .cornerRadius(8)
                        }
                    }
                    
                    // Appearance
                    settingsSection("Appearance") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Font Size")
                                    .frame(width: 100, alignment: .leading)
                                Slider(value: $state.fontSize, in: 12...24, step: 1)
                                Text("\(Int(state.fontSize))pt")
                                    .frame(width: 40)
                                    .font(.system(.body, design: .monospaced))
                            }
                            
                            HStack {
                                Text("Opacity")
                                    .frame(width: 100, alignment: .leading)
                                Slider(value: $state.overlayOpacity, in: 0.8...1.0, step: 0.05)
                                Text("\(Int(state.overlayOpacity * 100))%")
                                    .frame(width: 40)
                                    .font(.system(.body, design: .monospaced))
                            }
                        }
                    }
                    
                    // Ignore List
                    settingsSection("Ignore List") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Text containing these patterns will be ignored:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            IgnoreListEditor(state: state)
                        }
                    }
                    
                    // Advanced
                    settingsSection("Advanced") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Log File")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            HStack {
                                TextField("Log path", text: $state.logFilePath)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))
                                
                                Button("Open") {
                                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: state.logFilePath)
                                }
                            }
                        }
                    }
                    
                    // Info
                    settingsSection("Tips") {
                        VStack(alignment: .leading, spacing: 6) {
                            tipRow("Click overlay for options (copy, hide, ignore)")
                            tipRow("Hidden overlays: click any other → Show All")
                            tipRow("Press ⌘⌃T to toggle translation")
                        }
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Footer
            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.return)
            }
            .padding()
        }
        .frame(width: 400, height: 450)
    }
    
    @ViewBuilder
    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            
            content()
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
        }
    }
    
    @ViewBuilder
    private func tipRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
            Text(text)
                .font(.callout)
        }
    }
}

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
            if state.ignoredPatterns.isEmpty {
                Text("No patterns")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .padding(.vertical, 4)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(state.ignoredPatterns, id: \.self) { pattern in
                        PatternTag(pattern: pattern) {
                            state.removeIgnoredPattern(pattern)
                        }
                    }
                }
            }
        }
    }
    
    private func addPattern() {
        let trimmed = newPattern.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            state.addIgnoredPattern(trimmed)
            newPattern = ""
        }
    }
}

struct PatternTag: View {
    let pattern: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(pattern)
                .font(.caption)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .foregroundStyle(.blue)
        .cornerRadius(12)
    }
}

// Simple flow layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }
    
    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxWidth: CGFloat = 0
        
        let maxX = proposal.width ?? .infinity
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > maxX && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxWidth = max(maxWidth, currentX)
        }
        
        return (CGSize(width: maxWidth, height: currentY + lineHeight), positions)
    }
}
