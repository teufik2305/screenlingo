import XCTest
@testable import OverlayTranslator

final class IgnorePatternManagerTests: XCTestCase {
    
    var manager: IgnorePatternManager!
    var testStore: UserDefaults!
    
    override func setUp() {
        super.setUp()
        // Use isolated UserDefaults for testing (doesn't affect user preferences)
        testStore = UserDefaults(suiteName: "com.screenlingo.tests.ignorepatterns")!
        testStore.removePersistentDomain(forName: "com.screenlingo.tests.ignorepatterns")
        manager = IgnorePatternManager(store: testStore)
        // Clear any existing patterns
        manager.ignoredPatterns = []
    }
    
    override func tearDown() {
        // Clean up test storage
        testStore.removePersistentDomain(forName: "com.screenlingo.tests.ignorepatterns")
        testStore = nil
        manager = nil
        super.tearDown()
    }
    
    // MARK: - Basic Operations
    
    func testAddIgnoredPattern() {
        // Given
        let pattern = "error"
        
        // When
        manager.addIgnoredPattern(pattern)
        
        // Then
        XCTAssertTrue(manager.ignoredPatterns.contains(pattern))
        XCTAssertEqual(manager.ignoredPatterns.count, 1)
    }
    
    func testRemoveIgnoredPattern() {
        // Given
        let pattern = "error"
        manager.addIgnoredPattern(pattern)
        
        // When
        manager.removeIgnoredPattern(pattern)
        
        // Then
        XCTAssertFalse(manager.ignoredPatterns.contains(pattern))
        XCTAssertEqual(manager.ignoredPatterns.count, 0)
    }
    
    func testAddDuplicatePattern() {
        // Given
        let pattern = "error"
        
        // When
        manager.addIgnoredPattern(pattern)
        manager.addIgnoredPattern(pattern)
        
        // Then - should only add once
        XCTAssertEqual(manager.ignoredPatterns.count, 1)
    }
    
    func testAddEmptyString() {
        // Given
        let emptyPattern = ""
        
        // When
        manager.addIgnoredPattern(emptyPattern)
        
        // Then - should not add empty strings
        XCTAssertEqual(manager.ignoredPatterns.count, 0)
    }
    
    func testPatternsAreLowercased() {
        // Given
        let pattern = "ERROR"
        
        // When
        manager.addIgnoredPattern(pattern)
        
        // Then - should be stored as lowercase
        XCTAssertTrue(manager.ignoredPatterns.contains("error"))
        XCTAssertFalse(manager.ignoredPatterns.contains("ERROR"))
    }
    
    // MARK: - Text Filtering
    
    func testShouldIgnoreText_ExactMatch() {
        // Given
        manager.addIgnoredPattern("error")
        
        // When/Then
        XCTAssertTrue(manager.shouldIgnoreText("error"))
        XCTAssertTrue(manager.shouldIgnoreText("ERROR")) // case insensitive
        XCTAssertTrue(manager.shouldIgnoreText("Error"))
    }
    
    func testShouldIgnoreText_PartialMatch() {
        // Given
        manager.addIgnoredPattern("error")
        
        // When/Then - should match if text contains the pattern
        XCTAssertTrue(manager.shouldIgnoreText("An error occurred"))
        XCTAssertTrue(manager.shouldIgnoreText("Error: something went wrong"))
        XCTAssertTrue(manager.shouldIgnoreText("errorMessage"))
    }
    
    func testShouldIgnoreText_NoMatch() {
        // Given
        manager.addIgnoredPattern("error")
        
        // When/Then
        XCTAssertFalse(manager.shouldIgnoreText("warning"))
        XCTAssertFalse(manager.shouldIgnoreText("success"))
        XCTAssertFalse(manager.shouldIgnoreText("Hello world"))
    }
    
    func testShouldIgnoreText_EmptyText() {
        // Given
        manager.addIgnoredPattern("error")
        
        // When/Then
        XCTAssertFalse(manager.shouldIgnoreText(""))
    }
    
    func testShouldIgnoreText_NoPatterns() {
        // Given - no patterns added
        
        // When/Then - should not ignore anything
        XCTAssertFalse(manager.shouldIgnoreText("error"))
        XCTAssertFalse(manager.shouldIgnoreText("anything"))
    }
    
    // MARK: - Multiple Patterns
    
    func testMultiplePatterns() {
        // Given
        let patterns = ["error", "warning", "debug"]
        
        // When
        patterns.forEach { manager.addIgnoredPattern($0) }
        
        // Then
        XCTAssertEqual(manager.ignoredPatterns.count, 3)
        XCTAssertTrue(manager.shouldIgnoreText("An error occurred"))
        XCTAssertTrue(manager.shouldIgnoreText("Warning: check this"))
        XCTAssertTrue(manager.shouldIgnoreText("Debug mode enabled"))
        XCTAssertFalse(manager.shouldIgnoreText("Success"))
    }
    
    func testMultiplePatterns_FirstMatch() {
        // Given
        manager.addIgnoredPattern("error")
        manager.addIgnoredPattern("warning")
        
        // When/Then - should return true on first match
        XCTAssertTrue(manager.shouldIgnoreText("error and warning"))
    }
    
    // MARK: - Real-World Scenarios
    
    func testCommonUIElements() {
        // Given - common UI elements to ignore
        let uiPatterns = ["button", "menu", "toolbar", "©", "™"]
        
        // When
        uiPatterns.forEach { manager.addIgnoredPattern($0) }
        
        // Then
        XCTAssertTrue(manager.shouldIgnoreText("Click the button"))
        XCTAssertTrue(manager.shouldIgnoreText("Open menu"))
        XCTAssertTrue(manager.shouldIgnoreText("© 2024 Company"))
        XCTAssertFalse(manager.shouldIgnoreText("Hello world"))
    }
    
    func testSpecialCharacters() {
        // Given
        manager.addIgnoredPattern("©")
        manager.addIgnoredPattern("™")
        manager.addIgnoredPattern("®")
        
        // When/Then
        XCTAssertTrue(manager.shouldIgnoreText("© 2024"))
        XCTAssertTrue(manager.shouldIgnoreText("Product™"))
        XCTAssertTrue(manager.shouldIgnoreText("Brand®"))
    }
    
    func testWhitespaceHandling() {
        // Given
        let pattern = "  error  "
        
        // When
        manager.addIgnoredPattern(pattern)
        
        // Then - should trim whitespace
        XCTAssertTrue(manager.ignoredPatterns.contains("error"))
        XCTAssertTrue(manager.shouldIgnoreText("An error occurred"))
    }
}
