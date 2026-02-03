import XCTest
import CoreGraphics
@testable import OverlayTranslator

final class ADECacheTests: XCTestCase {
    
    var cache: ADECache!
    
    override func setUp() {
        super.setUp()
        cache = ADECache()
    }
    
    func testSetAndGet_WhenBlockStored_ReturnsCorrectBlock() async {
        // Given
        let hash = "test_hash_123"
        let blocks = [
            ExtractedTextBlock(text: "Hello", boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.1))
        ]
        
        // When
        await cache.set(hash: hash, blocks: blocks)
        let result = await cache.get(hash: hash)
        
        // Then
        XCTAssertEqual(result?.count, 1)
        XCTAssertEqual(result?.first?.text, "Hello")
    }
    
    func testGet_WhenHashNotStored_ReturnsNil() async {
        // Given
        let hash = "nonexistent_hash"
        
        // When
        let result = await cache.get(hash: hash)
        
        // Then
        XCTAssertNil(result)
    }
    
    func testLRU_EvictsOldest_WhenCapacityExceeded() async {
        // Given - Set max size to small number for testing
        // Note: ADECache has maxSize = 50, we'll add 51 items
        
        for i in 0..<52 {
            let hash = "hash_\(i)"
            let blocks = [ExtractedTextBlock(text: "Text \(i)", boundingBox: CGRect.zero)]
            await cache.set(hash: hash, blocks: blocks)
        }
        
        // When - Check first item was evicted
        let firstResult = await cache.get(hash: "hash_0")
        let lastResult = await cache.get(hash: "hash_51")
        
        // Then - First should be evicted, last should exist
        XCTAssertNil(firstResult, "First item should be evicted (LRU)")
        XCTAssertNotNil(lastResult, "Last item should exist")
    }
    
    func testSet_UpdatesExistingHash() async {
        // Given
        let hash = "update_test"
        let blocks1 = [ExtractedTextBlock(text: "Original", boundingBox: CGRect.zero)]
        let blocks2 = [ExtractedTextBlock(text: "Updated", boundingBox: CGRect(x: 0.5, y: 0.5, width: 0.1, height: 0.1))]
        
        // When
        await cache.set(hash: hash, blocks: blocks1)
        await cache.set(hash: hash, blocks: blocks2)
        let result = await cache.get(hash: hash)
        
        // Then
        XCTAssertEqual(result?.first?.text, "Updated")
        XCTAssertEqual(result?.first?.boundingBox.origin.x, 0.5)
    }
}

// MARK: - Mock ExtractedTextBlock for Testing
extension ExtractedTextBlock {
    init(text: String, boundingBox: CGRect) {
        self.init(
            id: UUID(),
            text: text,
            boundingBox: boundingBox,
            type: .unknown,
            speaker: nil,
            readingOrder: 0,
            confidence: 1.0,
            merged: false
        )
    }
}
