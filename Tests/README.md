# Tests

## Running

```bash
swift test                              # All tests
swift test --filter TranslationCache   # Specific test class
swift test --parallel                   # Parallel execution
```

Or in Xcode: `Cmd+U`

## Structure

```
Tests/
├── ADETests/                              # Agentic Document Extraction tests
│   ├── ADEDetectedProviderTests.swift     # Provider auto-detection from URLs
│   ├── ADECacheTests.swift                # Perceptual hash caching
│   ├── ADECoordinateTests.swift           # Coordinate conversion (0-1 to screen)
│   └── ADEErrorTests.swift                # ADE error handling & models
├── CacheTests/
│   └── TranslationCacheTests.swift       # Cache operations, LRU, normalization
├── EngineTests/
│   └── WindowCaptureServiceTests.swift   # Image hashing, screen detection
├── ManagerTests/
│   ├── ExcludedAppsManagerTests.swift    # App exclusion logic
│   └── IgnorePatternManagerTests.swift   # Pattern filtering
├── StateTests/
│   └── TranslatorStateTests.swift        # Settings, language utils, service detection
```

### Adding ADE Tests

When adding ADE providers, consider testing:
- Provider auto-detection from URL patterns
- Coordinate conversion (normalized 0-1 to screen coordinates)
- Response parsing (JSON to ExtractedTextBlock)
- Fallback to OCR on ADE failure
- Cache deduplication (perceptual hashing)

## Writing Tests

```swift
import XCTest
@testable import OverlayTranslator

final class MyTests: XCTestCase {
    var sut: MyClass!  // System Under Test
    
    override func setUp() {
        super.setUp()
        sut = MyClass()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    func testSomething_WhenCondition_ThenExpected() {
        // Given
        let input = "test"
        
        // When
        let result = sut.process(input)
        
        // Then
        XCTAssertEqual(result, "expected")
    }
}
```

## Guidelines

- Use `Given-When-Then` structure
- Name tests: `test[Method]_When[Condition]_Then[Expected]`
- One assertion per test when possible
- Clean up in `tearDown`
- Test edge cases: empty, nil, special chars, large inputs
- **Use isolated storage** - never modify user preferences

## Test Isolation

Managers use UserDefaults for persistence. Tests MUST use isolated storage to avoid modifying user preferences:

```swift
var testStore: UserDefaults!

override func setUp() {
    super.setUp()
    // Create isolated test storage
    testStore = UserDefaults(suiteName: "com.screenlingo.tests.mytest")!
    testStore.removePersistentDomain(forName: "com.screenlingo.tests.mytest")
    
    // Inject test store
    manager = MyManager(store: testStore)
}

override func tearDown() {
    // Clean up
    testStore.removePersistentDomain(forName: "com.screenlingo.tests.mytest")
    testStore = nil
    super.tearDown()
}
```

## Adding Tests

1. Create file in appropriate folder (`CacheTests/`, `ManagerTests/`, etc.)
2. Import `@testable import OverlayTranslator`
3. Extend `XCTestCase`
4. Run with `swift test`
