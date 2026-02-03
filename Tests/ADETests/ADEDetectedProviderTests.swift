import XCTest
@testable import OverlayTranslator

final class ADEDetectedProviderTests: XCTestCase {
    
    func testDetect_WhenGeminiURL_ReturnsGemini() {
        // Given
        let urls = [
            "https://generativelanguage.googleapis.com/v1beta",
            "https://generativelanguage.googleapis.com/v1",
            "https://generativelanguage.googleapis.com"
        ]
        
        // When & Then
        for url in urls {
            let detected = ADEDetectedProvider.detect(from: url)
            XCTAssertEqual(detected, .gemini, "URL \(url) should be detected as Gemini")
        }
    }
    
    func testDetect_WhenAnthropicURL_ReturnsAnthropic() {
        // Given
        let urls = [
            "https://api.anthropic.com/v1/messages",
            "https://api.anthropic.com",
            "https://claude.ai/api"
        ]
        
        // When & Then
        for url in urls {
            let detected = ADEDetectedProvider.detect(from: url)
            XCTAssertEqual(detected, .anthropic, "URL \(url) should be detected as Anthropic")
        }
    }
    
    func testDetect_WhenOpenAIURL_ReturnsOpenAI() {
        // Given
        let urls = [
            "https://api.openai.com/v1/chat/completions",
            "https://api.openai.com",
            "https://openai.com/api"
        ]
        
        // When & Then
        for url in urls {
            let detected = ADEDetectedProvider.detect(from: url)
            XCTAssertEqual(detected, .openAI, "URL \(url) should be detected as OpenAI")
        }
    }
    
    func testDetect_WhenLocalURL_ReturnsLocal() {
        // Given
        let urls = [
            "http://localhost:11434/v1/chat/completions",
            "http://127.0.0.1:8080/v1/chat",
            "http://localhost:3000"
        ]
        
        // When & Then
        for url in urls {
            let detected = ADEDetectedProvider.detect(from: url)
            XCTAssertEqual(detected, .local, "URL \(url) should be detected as Local")
        }
    }
    
    func testDetect_WhenUnknownURL_ReturnsOther() {
        // Given
        let urls = [
            "https://api.example.com/v1",
            "https://custom.provider.io/chat",
            "http://192.168.1.100:8080"
        ]
        
        // When & Then
        for url in urls {
            let detected = ADEDetectedProvider.detect(from: url)
            XCTAssertEqual(detected, .other, "URL \(url) should be detected as Other")
        }
    }
    
    func testAllCases_HaveValidProperties() {
        // Verify all enum cases have valid display names and icons
        for provider in ADEDetectedProvider.allCases {
            XCTAssertFalse(provider.displayName.isEmpty, "\(provider) should have a display name")
            XCTAssertFalse(provider.icon.isEmpty, "\(provider) should have an icon")
            XCTAssertFalse(provider.color.isEmpty, "\(provider) should have a color")
        }
    }
}
