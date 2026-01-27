import XCTest
@testable import OverlayTranslator

final class TranslatorStateTests: XCTestCase {
    
    var state: TranslatorState!
    
    override func setUp() {
        super.setUp()
        state = TranslatorState()
    }
    
    override func tearDown() {
        state = nil
        super.tearDown()
    }
    
    // MARK: - Display Mode
    // Note: TranslatorState uses @AppStorage which reads from UserDefaults.
    // Tests verify properties can be set/read, not specific default values
    // (defaults may vary based on user preferences).
    
    func testDisplayMode_CanSetToBox() {
        // When
        state.overlayDisplayMode = 0
        
        // Then
        XCTAssertEqual(state.overlayDisplayMode, 0)
    }
    
    func testDisplayMode_CanSetToOutline() {
        // When
        state.overlayDisplayMode = 1
        
        // Then
        XCTAssertEqual(state.overlayDisplayMode, 1)
    }
    
    // MARK: - Box Settings
    
    func testBoxPaddingH_CanSet() {
        // When
        state.boxPaddingH = 20
        
        // Then
        XCTAssertEqual(state.boxPaddingH, 20)
    }
    
    func testBoxPaddingV_CanSet() {
        // When
        state.boxPaddingV = 15
        
        // Then
        XCTAssertEqual(state.boxPaddingV, 15)
    }
    
    func testBoxCornerRadius_CanSet() {
        // When
        state.boxCornerRadius = 10
        
        // Then
        XCTAssertEqual(state.boxCornerRadius, 10)
    }
    
    func testBoxBackgroundColor_CanSet() {
        // When
        state.boxBackgroundColorHex = "#FF0000"
        
        // Then
        XCTAssertEqual(state.boxBackgroundColorHex, "#FF0000")
    }
    
    func testBoxTextColor_CanSet() {
        // When
        state.boxTextColorHex = "#00FF00"
        
        // Then
        XCTAssertEqual(state.boxTextColorHex, "#00FF00")
    }
    
    func testBoxBorderWidth_CanSet() {
        // When
        state.boxBorderWidth = 2.5
        
        // Then
        XCTAssertEqual(state.boxBorderWidth, 2.5)
    }
    
    func testBoxShadowEnabled_CanToggle() {
        // When
        let original = state.boxShadowEnabled
        state.boxShadowEnabled = !original
        
        // Then
        XCTAssertEqual(state.boxShadowEnabled, !original)
    }
    
    // MARK: - Outline Settings
    
    func testOutlineWidth_CanSet() {
        // When
        state.outlineWidth = 3.5
        
        // Then
        XCTAssertEqual(state.outlineWidth, 3.5)
    }
    
    func testOutlineColor_CanSet() {
        // When
        state.outlineColorHex = "#0000FF"
        
        // Then
        XCTAssertEqual(state.outlineColorHex, "#0000FF")
    }
    
    func testTextColor_CanSet() {
        // When
        state.textColorHex = "#FFFF00"
        
        // Then
        XCTAssertEqual(state.textColorHex, "#FFFF00")
    }
    
    // MARK: - Multi-Monitor
    
    func testMultiMonitorEnabled_CanToggle() {
        // When
        let original = state.multiMonitorEnabled
        state.multiMonitorEnabled = !original
        
        // Then
        XCTAssertEqual(state.multiMonitorEnabled, !original)
    }
    
    // MARK: - Language Utilities
    
    func testLanguageName_KnownCode() {
        let name = state.languageName(for: "en")
        XCTAssertEqual(name, "English")
    }
    
    func testLanguageName_Auto() {
        let name = state.languageName(for: "auto")
        XCTAssertEqual(name, "Auto Detect")
    }
    
    func testSwapLanguages_SwapsCorrectly() {
        // Given
        state.sourceLanguage = "fr"
        state.targetLanguage = "en"
        
        // When
        state.swapLanguages()
        
        // Then
        XCTAssertEqual(state.sourceLanguage, "en")
        XCTAssertEqual(state.targetLanguage, "fr")
    }
    
    func testSwapLanguages_DoesNotSwapWhenSourceIsAuto() {
        // Given
        state.sourceLanguage = "auto"
        state.targetLanguage = "en"
        
        // When
        state.swapLanguages()
        
        // Then - should not swap
        XCTAssertEqual(state.sourceLanguage, "auto")
        XCTAssertEqual(state.targetLanguage, "en")
    }
    
    // MARK: - Service Detection
    
    func testUseAppleTranslation() {
        // When
        state.translationServiceRaw = 0
        
        // Then
        XCTAssertTrue(state.useAppleTranslation)
        XCTAssertFalse(state.useLibreTranslate)
        XCTAssertFalse(state.useLLM)
    }
    
    func testUseLibreTranslate() {
        // When
        state.translationServiceRaw = 1
        
        // Then
        XCTAssertFalse(state.useAppleTranslation)
        XCTAssertTrue(state.useLibreTranslate)
        XCTAssertFalse(state.useLLM)
    }
    
    func testUseLLM() {
        // When
        state.translationServiceRaw = 3
        
        // Then
        XCTAssertFalse(state.useAppleTranslation)
        XCTAssertFalse(state.useLibreTranslate)
        XCTAssertTrue(state.useLLM)
    }
    
    // MARK: - LLM Provider Detection
    
    func testDetectedLLMProvider_OpenAI() {
        // Given
        state.llmApiUrl = "https://api.openai.com/v1/chat/completions"
        
        // Then
        XCTAssertEqual(state.detectedLLMProvider, .openai)
    }
    
    func testDetectedLLMProvider_Anthropic() {
        // Given
        state.llmApiUrl = "https://api.anthropic.com/v1/messages"
        
        // Then
        XCTAssertEqual(state.detectedLLMProvider, .anthropic)
    }
    
    func testDetectedLLMProvider_Local() {
        // Given
        state.llmApiUrl = "http://localhost:11434/api/chat"
        
        // Then
        XCTAssertEqual(state.detectedLLMProvider, .local)
    }
    
    // MARK: - Cache Path
    
    func testEffectiveCacheFilePath_Default() {
        // Given
        state.cacheFilePath = ""
        
        // Then - should return default path
        XCTAssertTrue(state.effectiveCacheFilePath.contains("ScreenLingo"))
        XCTAssertTrue(state.effectiveCacheFilePath.hasSuffix("translation_cache.json"))
    }
    
    func testEffectiveCacheFilePath_Custom() {
        // Given
        let customPath = "/custom/path/cache.json"
        state.cacheFilePath = customPath
        
        // Then
        XCTAssertEqual(state.effectiveCacheFilePath, customPath)
    }
}
