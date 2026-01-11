import SwiftUI

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
