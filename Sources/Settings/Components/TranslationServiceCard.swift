import SwiftUI

struct TranslationServiceCard: View {
    let service: TranslationServiceType
    let isSelected: Bool
    let isAvailable: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: service.icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? service.color : .secondary)
                
                Text(service.name)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                
                Text(service.shortDescription)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? service.color.opacity(0.12) : Color(nsColor: .windowBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? service.color : Color.clear, lineWidth: 2)
            )
            .opacity(isAvailable ? 1.0 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
    }
}
