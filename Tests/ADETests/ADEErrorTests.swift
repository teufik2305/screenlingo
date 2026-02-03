import XCTest
@testable import OverlayTranslator

final class ADEErrorTests: XCTestCase {
    
    func testADEError_LocalizedDescription() {
        // Given
        let extractionError = ADEError.extractionFailed("Connection timeout")
        let modelError = ADEError.modelNotAvailable("claude-3")
        let responseError = ADEError.invalidResponse
        let timeoutError = ADEError.timeout
        let noVisionError = ADEError.noVisionSupport
        
        // Then - Verify descriptions are meaningful
        XCTAssertTrue(extractionError.localizedDescription.contains("Connection timeout"))
        XCTAssertTrue(modelError.localizedDescription.contains("claude-3"))
        XCTAssertFalse(responseError.localizedDescription.isEmpty)
        XCTAssertFalse(timeoutError.localizedDescription.isEmpty)
        XCTAssertFalse(noVisionError.localizedDescription.isEmpty)
    }
    
    func testADEError_ErrorConformance() {
        // Given & When & Then
        // Verify all error cases can be thrown and caught
        let errors: [ADEError] = [
            .noVisionSupport,
            .extractionFailed("test"),
            .invalidResponse,
            .modelNotAvailable("test-model"),
            .timeout
        ]
        
        for error in errors {
            XCTAssertNotNil(error as Error, "ADEError should conform to Error protocol")
            XCTAssertNotNil(error.errorDescription, "Should have localized description")
        }
    }
}

// MARK: - ADEModels Tests
final class ADEModelsTests: XCTestCase {
    
    func testTextType_InitFromRawValue() {
        // Given & When & Then
        XCTAssertEqual(TextType(rawValue: "speech"), .speech)
        XCTAssertEqual(TextType(rawValue: "narration"), .narration)
        XCTAssertEqual(TextType(rawValue: "thought"), .thought)
        XCTAssertEqual(TextType(rawValue: "sound_effect"), .soundEffect)
        XCTAssertEqual(TextType(rawValue: "title"), .title)
        XCTAssertEqual(TextType(rawValue: "caption"), .caption)
        XCTAssertEqual(TextType(rawValue: "unknown"), .unknown)
        XCTAssertNil(TextType(rawValue: "invalid"))
    }
    
    func testTextType_RawValues() {
        // Given & When & Then
        XCTAssertEqual(TextType.speech.rawValue, "speech")
        XCTAssertEqual(TextType.narration.rawValue, "narration")
        XCTAssertEqual(TextType.thought.rawValue, "thought")
        XCTAssertEqual(TextType.soundEffect.rawValue, "sound_effect")
        XCTAssertEqual(TextType.title.rawValue, "title")
        XCTAssertEqual(TextType.caption.rawValue, "caption")
        XCTAssertEqual(TextType.unknown.rawValue, "unknown")
    }
    
    func testExtractedTextBlock_DefaultValues() {
        // Given
        let block = ExtractedTextBlock(
            text: "Test",
            boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4)
        )
        
        // Then
        XCTAssertEqual(block.text, "Test")
        XCTAssertEqual(block.boundingBox.origin.x, 0.1)
        XCTAssertEqual(block.boundingBox.origin.y, 0.2)
        XCTAssertEqual(block.type, .unknown)
        XCTAssertNil(block.speaker)
        XCTAssertEqual(block.readingOrder, 0)
        XCTAssertEqual(block.confidence, 1.0)
        XCTAssertEqual(block.merged, false)
    }
}
