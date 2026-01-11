import SwiftUI

struct OverlayPreview: View {
    let fontSize: Double
    let opacity: Double
    
    var body: some View {
        ZStack {
            // Checkerboard pattern to show transparency
            GeometryReader { geo in
                let cellSize: CGFloat = 10
                let cols = Int(ceil(geo.size.width / cellSize))
                let rows = Int(ceil(geo.size.height / cellSize))
                
                Canvas { context, size in
                    for row in 0..<rows {
                        for col in 0..<cols {
                            let isLight = (row + col) % 2 == 0
                            let rect = CGRect(
                                x: CGFloat(col) * cellSize,
                                y: CGFloat(row) * cellSize,
                                width: cellSize,
                                height: cellSize
                            )
                            context.fill(
                                Path(rect),
                                with: .color(isLight ? Color.gray.opacity(0.2) : Color.gray.opacity(0.4))
                            )
                        }
                    }
                }
            }
            .cornerRadius(6)
            
            // Overlay preview
            Text("Preview text")
                .font(.system(size: fontSize))
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(opacity))
                .foregroundColor(.white)
                .cornerRadius(6)
        }
        .frame(height: 44)
    }
}
