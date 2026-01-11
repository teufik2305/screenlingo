import SwiftUI

struct AppTag: View {
    let bundleId: String
    let onRemove: () -> Void
    
    var displayName: String {
        switch bundleId {
        case "com.todesktop.230313mzl4w4u92": return "Cursor"
        case "com.microsoft.VSCode": return "VS Code"
        case "com.apple.dt.Xcode": return "Xcode"
        case "com.apple.Terminal": return "Terminal"
        default: return bundleId.components(separatedBy: ".").last ?? bundleId
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Text(displayName)
                .font(.caption)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.purple.opacity(0.1))
        .foregroundStyle(.purple)
        .cornerRadius(12)
        .help(bundleId)
    }
}
