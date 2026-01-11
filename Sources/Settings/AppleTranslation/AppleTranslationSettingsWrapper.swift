import SwiftUI

@available(macOS 26.0, *)
struct AppleTranslationSettingsWrapper: View {
    @ObservedObject var state: TranslatorState
    
    var body: some View {
        if #available(macOS 26.0, *) {
            AppleTranslationSettings(state: state)
        } else {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Requires macOS 15+ • Will fallback to Google API")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }
}