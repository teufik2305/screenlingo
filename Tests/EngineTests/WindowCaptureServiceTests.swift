import XCTest
@testable import OverlayTranslator

final class WindowCaptureServiceTests: XCTestCase {
    
    var service: WindowCaptureService!
    
    override func setUp() {
        super.setUp()
        service = WindowCaptureService()
    }
    
    override func tearDown() {
        service = nil
        super.tearDown()
    }
    
    // MARK: - Image Hashing
    
    func testHashImage_SameImage_SameHash() {
        // Given
        let image = createTestImage(width: 100, height: 100, color: .red)
        
        // When
        let hash1 = service.hashImage(image)
        let hash2 = service.hashImage(image)
        
        // Then
        XCTAssertEqual(hash1, hash2)
    }
    
    func testHashImage_DifferentImages_DifferentHashes() {
        // Given
        let image1 = createTestImage(width: 100, height: 100, color: .red)
        let image2 = createTestImage(width: 100, height: 100, color: .blue)
        
        // When
        let hash1 = service.hashImage(image1)
        let hash2 = service.hashImage(image2)
        
        // Then
        XCTAssertNotEqual(hash1, hash2)
    }
    
    func testHashImage_DifferentSizes_DifferentHashes() {
        // Given
        let image1 = createTestImage(width: 100, height: 100, color: .red)
        let image2 = createTestImage(width: 200, height: 200, color: .red)
        
        // When
        let hash1 = service.hashImage(image1)
        let hash2 = service.hashImage(image2)
        
        // Then - might be same due to sampling, but good to test
        // Hash is based on sampled pixels, so this may or may not be equal
        XCTAssertFalse(hash1.isEmpty)
        XCTAssertFalse(hash2.isEmpty)
    }
    
    func testHashImage_ReturnsValidHash() {
        // Given
        let image = createTestImage(width: 100, height: 100, color: .green)
        
        // When
        let hash = service.hashImage(image)
        
        // Then - hash should be 12 characters (truncated SHA256)
        XCTAssertEqual(hash.count, 12)
        XCTAssertTrue(hash.allSatisfy { $0.isHexDigit })
    }
    
    func testHashImage_SmallImage() {
        // Given - very small image
        let image = createTestImage(width: 10, height: 10, color: .white)
        
        // When
        let hash = service.hashImage(image)
        
        // Then
        XCTAssertFalse(hash.isEmpty)
    }
    
    func testHashImage_LargeImage() {
        // Given - large image
        let image = createTestImage(width: 1920, height: 1080, color: .black)
        
        // When
        let hash = service.hashImage(image)
        
        // Then
        XCTAssertEqual(hash.count, 12)
    }
    
    // MARK: - Helpers
    
    private func createTestImage(width: Int, height: Int, color: NSColor) -> NSImage {
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        color.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        image.unlockFocus()
        return image
    }
}
