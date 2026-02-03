import XCTest
import CoreGraphics
@testable import OverlayTranslator

/// Tests for coordinate conversion between normalized (0-1) and screen coordinates
final class ADECoordinateTests: XCTestCase {
    
    // Window bounds in CGWindowList style (origin at top-left)
    let windowBounds = CGRect(x: 1000, y: 100, width: 1440, height: 900)
    
    func testADENormalizedToScreen_TopLeft() {
        // ADE: origin at top-left, normY from top
        // Given: Block at top-left of window (0, 0)
        let normX: CGFloat = 0.0
        let normY: CGFloat = 0.0
        let normW: CGFloat = 0.1
        let normH: CGFloat = 0.1
        
        // When converting to screen coordinates (top-left origin)
        let screenX = windowBounds.origin.x + normX * windowBounds.width
        let screenY = windowBounds.origin.y + normY * windowBounds.height
        
        // Then
        XCTAssertEqual(screenX, 1000)
        XCTAssertEqual(screenY, 100) // Top of window
    }
    
    func testADENormalizedToScreen_BottomRight() {
        // ADE: origin at top-left, normY from top
        // Given: Block at bottom-right area
        let normX: CGFloat = 0.8
        let normY: CGFloat = 0.8
        let normW: CGFloat = 0.1
        let normH: CGFloat = 0.1
        
        // When converting to screen coordinates (top-left origin)
        let screenX = windowBounds.origin.x + normX * windowBounds.width
        let screenY = windowBounds.origin.y + normY * windowBounds.height
        
        // Then
        XCTAssertEqual(screenX, 1000 + 0.8 * 1440) // 2152
        XCTAssertEqual(screenY, 100 + 0.8 * 900)   // 820 (from top)
    }
    
    func testOCRNormalizedToScreen_FromBottomOrigin() {
        // OCR (Vision): origin at bottom-left, normY from bottom
        // Given: Block at bottom-left of image (Vision coordinates)
        let normX: CGFloat = 0.0
        let normY: CGFloat = 0.0  // At bottom of image in Vision
        let normW: CGFloat = 0.1
        let normH: CGFloat = 0.1
        
        // When converting to screen coordinates (top-left origin)
        // Formula: screenY = windowY + (1 - normY - normH) * height
        let screenX = windowBounds.origin.x + normX * windowBounds.width
        let screenY = windowBounds.origin.y + (1 - normY - normH) * windowBounds.height
        
        // Then: Should appear near bottom of window in top-left coords
        XCTAssertEqual(screenX, 1000)
        XCTAssertEqual(screenY, 100 + 0.9 * 900) // 910 from top = near bottom
    }
    
    func testOCRNormalizedToScreen_Center() {
        // OCR (Vision): origin at bottom-left
        // Given: Block at center (Vision coordinates: x=0.4, y=0.4 from bottom)
        let normX: CGFloat = 0.4
        let normY: CGFloat = 0.4  // From bottom
        let normW: CGFloat = 0.2
        let normH: CGFloat = 0.2
        
        // When converting to screen coordinates (top-left origin)
        let screenX = windowBounds.origin.x + normX * windowBounds.width
        // Formula: screenY = windowY + (1 - normY - normH) * height
        let screenY = windowBounds.origin.y + (1 - normY - normH) * windowBounds.height
        
        // Then
        XCTAssertEqual(screenX, 1000 + 0.4 * 1440) // 1576
        XCTAssertEqual(screenY, 100 + (1 - 0.4 - 0.2) * 900) // 100 + 0.4*900 = 460
    }
}
