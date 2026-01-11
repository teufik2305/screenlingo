import XCTest
@testable import OverlayTranslator

final class TranslationCacheTests: XCTestCase {
    
    var cache: TranslationCache!
    
    override func setUp() {
        super.setUp()
        cache = TranslationCache(maxSize: 3) // Small size for testing
    }
    
    override func tearDown() {
        cache = nil
        super.tearDown()
    }
    
    // MARK: - Basic Operations
    
    func testSetAndGet() {
        // Given
        let text = "Hello"
        let translation = "Bonjour"
        
        // When
        cache.set(text, translation: translation)
        
        // Then
        XCTAssertEqual(cache.get(text), translation)
    }
    
    func testGetNonExistent() {
        // When/Then
        XCTAssertNil(cache.get("nonexistent"))
    }
    
    func testOverwriteExisting() {
        // Given
        let text = "Hello"
        cache.set(text, translation: "Bonjour")
        
        // When
        cache.set(text, translation: "Salut")
        
        // Then
        XCTAssertEqual(cache.get(text), "Salut")
    }
    
    // MARK: - Normalization
    
    func testNormalization_Whitespace() {
        // Given
        cache.set("Hello  World", translation: "Bonjour Monde")
        
        // When/Then - should normalize whitespace
        XCTAssertEqual(cache.get("Hello World"), "Bonjour Monde")
        XCTAssertEqual(cache.get("hello world"), "Bonjour Monde")
    }
    
    func testNormalization_Case() {
        // Given
        cache.set("Hello", translation: "Bonjour")
        
        // When/Then - should be case insensitive
        XCTAssertEqual(cache.get("hello"), "Bonjour")
        XCTAssertEqual(cache.get("HELLO"), "Bonjour")
        XCTAssertEqual(cache.get("HeLLo"), "Bonjour")
    }
    
    func testNormalization_LeadingTrailingWhitespace() {
        // Given
        cache.set("  Hello  ", translation: "Bonjour")
        
        // When/Then
        XCTAssertEqual(cache.get("Hello"), "Bonjour")
        XCTAssertEqual(cache.get("  Hello"), "Bonjour")
        XCTAssertEqual(cache.get("Hello  "), "Bonjour")
    }
    
    func testNormalization_Newlines() {
        // Given
        cache.set("Hello\nWorld", translation: "Bonjour Monde")
        
        // When/Then - newlines are trimmed from ends, but internal newlines remain
        // The normalize function only trims whitespace/newlines, doesn't replace them
        XCTAssertEqual(cache.get("hello\nworld"), "Bonjour Monde")
    }
    
    // MARK: - LRU Eviction
    
    func testLRUEviction() {
        // Given - cache size is 3
        cache.set("A", translation: "A_trans")
        cache.set("B", translation: "B_trans")
        cache.set("C", translation: "C_trans")
        
        // When - add a 4th item
        cache.set("D", translation: "D_trans")
        
        // Then - oldest (A) should be evicted
        XCTAssertNil(cache.get("A"))
        XCTAssertEqual(cache.get("B"), "B_trans")
        XCTAssertEqual(cache.get("C"), "C_trans")
        XCTAssertEqual(cache.get("D"), "D_trans")
    }
    
    func testLRUEviction_InsertionOrder() {
        // Given
        cache.set("A", translation: "A_trans")
        cache.set("B", translation: "B_trans")
        cache.set("C", translation: "C_trans")
        
        // When - access A (but this doesn't update order in current implementation)
        _ = cache.get("A")
        
        // Then add D - A should be evicted (oldest insertion, not access)
        cache.set("D", translation: "D_trans")
        
        // Note: Current implementation uses insertion order, not access order
        XCTAssertNil(cache.get("A")) // Evicted (oldest insertion)
        XCTAssertEqual(cache.get("B"), "B_trans")
        XCTAssertEqual(cache.get("C"), "C_trans")
        XCTAssertEqual(cache.get("D"), "D_trans")
    }
    
    // MARK: - Clear
    
    func testClear() {
        // Given
        cache.set("A", translation: "A_trans")
        cache.set("B", translation: "B_trans")
        
        // When
        cache.clear()
        
        // Then
        XCTAssertNil(cache.get("A"))
        XCTAssertNil(cache.get("B"))
    }
    
    // MARK: - Edge Cases
    
    func testEmptyString() {
        // Given
        cache.set("", translation: "Empty")
        
        // When/Then
        XCTAssertEqual(cache.get(""), "Empty")
    }
    
    func testVeryLongString() {
        // Given
        let longText = String(repeating: "A", count: 10000)
        let translation = "Long translation"
        
        // When
        cache.set(longText, translation: translation)
        
        // Then
        XCTAssertEqual(cache.get(longText), translation)
    }
    
    func testSpecialCharacters() {
        // Given
        let text = "Hello! @#$%^&*() 你好 مرحبا"
        let translation = "Special chars"
        
        // When
        cache.set(text, translation: translation)
        
        // Then
        XCTAssertEqual(cache.get(text), translation)
    }
    
    // MARK: - Performance
    
    func testPerformance_LargeCache() {
        // Given
        let largeCache = TranslationCache(maxSize: 1000)
        
        // When/Then
        measure {
            for i in 0..<1000 {
                largeCache.set("Text \(i)", translation: "Translation \(i)")
            }
        }
    }
    
    func testPerformance_Lookups() {
        // Given
        for i in 0..<100 {
            cache.set("Text \(i)", translation: "Translation \(i)")
        }
        
        // When/Then
        measure {
            for i in 0..<100 {
                _ = cache.get("Text \(i)")
            }
        }
    }
}
