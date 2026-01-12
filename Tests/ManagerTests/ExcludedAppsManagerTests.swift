import XCTest
@testable import OverlayTranslator

final class ExcludedAppsManagerTests: XCTestCase {
    
    var manager: ExcludedAppsManager!
    var testStore: UserDefaults!
    
    override func setUp() {
        super.setUp()
        // Use isolated UserDefaults for testing (doesn't affect user preferences)
        testStore = UserDefaults(suiteName: "com.screenlingo.tests.excludedapps")!
        testStore.removePersistentDomain(forName: "com.screenlingo.tests.excludedapps")
        manager = ExcludedAppsManager(store: testStore)
        // Clear any existing apps
        manager.excludedApps = []
    }
    
    override func tearDown() {
        // Clean up test storage
        testStore.removePersistentDomain(forName: "com.screenlingo.tests.excludedapps")
        testStore = nil
        manager = nil
        super.tearDown()
    }
    
    // MARK: - Basic Operations
    
    func testAddExcludedApp() {
        // Given
        let bundleId = "com.example.app"
        
        // When
        manager.addExcludedApp(bundleId)
        
        // Then
        XCTAssertTrue(manager.excludedApps.contains(bundleId))
        XCTAssertEqual(manager.excludedApps.count, 1)
    }
    
    func testRemoveExcludedApp() {
        // Given
        let bundleId = "com.example.app"
        manager.addExcludedApp(bundleId)
        
        // When
        manager.removeExcludedApp(bundleId)
        
        // Then
        XCTAssertFalse(manager.excludedApps.contains(bundleId))
        XCTAssertEqual(manager.excludedApps.count, 0)
    }
    
    func testAddDuplicateApp() {
        // Given
        let bundleId = "com.example.app"
        
        // When
        manager.addExcludedApp(bundleId)
        manager.addExcludedApp(bundleId)
        
        // Then - should only add once
        XCTAssertEqual(manager.excludedApps.count, 1)
    }
    
    func testAddEmptyString() {
        // Given
        let emptyId = ""
        
        // When
        manager.addExcludedApp(emptyId)
        
        // Then - should not add empty strings
        XCTAssertEqual(manager.excludedApps.count, 0)
    }
    
    func testAddWhitespaceString() {
        // Given
        let whitespaceId = "   "
        
        // When
        manager.addExcludedApp(whitespaceId)
        
        // Then - should not add whitespace-only strings
        XCTAssertEqual(manager.excludedApps.count, 0)
    }
    
    // MARK: - Checking Exclusion
    
    func testIsAppExcluded_ExactMatch() {
        // Given
        let bundleId = "com.example.app"
        manager.addExcludedApp(bundleId)
        
        // When/Then
        XCTAssertTrue(manager.isAppExcluded(bundleId))
    }
    
    func testIsAppExcluded_PartialMatch() {
        // Given
        manager.addExcludedApp("com.example")
        
        // When/Then - should match if bundle ID contains the excluded string
        XCTAssertTrue(manager.isAppExcluded("com.example.app"))
        XCTAssertTrue(manager.isAppExcluded("com.example.another"))
    }
    
    func testIsAppExcluded_CaseInsensitive() {
        // Given
        manager.addExcludedApp("com.example.app")
        
        // When/Then - should be case insensitive
        XCTAssertTrue(manager.isAppExcluded("COM.EXAMPLE.APP"))
        XCTAssertTrue(manager.isAppExcluded("Com.Example.App"))
    }
    
    func testIsAppExcluded_Nil() {
        // Given
        manager.addExcludedApp("com.example.app")
        
        // When/Then - nil should return false
        XCTAssertFalse(manager.isAppExcluded(nil))
    }
    
    func testIsAppExcluded_NotExcluded() {
        // Given
        manager.addExcludedApp("com.example.app")
        
        // When/Then
        XCTAssertFalse(manager.isAppExcluded("com.other.app"))
    }
    
    // MARK: - Multiple Apps
    
    func testMultipleApps() {
        // Given
        let apps = ["com.example.app1", "com.example.app2", "com.other.app"]
        
        // When
        apps.forEach { manager.addExcludedApp($0) }
        
        // Then
        XCTAssertEqual(manager.excludedApps.count, 3)
        apps.forEach { app in
            XCTAssertTrue(manager.isAppExcluded(app))
        }
    }
    
    // MARK: - Real-World Scenarios
    
    func testRealWorldBundleIds() {
        // Given - common apps to exclude
        let commonApps = [
            "com.microsoft.VSCode",
            "com.apple.dt.Xcode",
            "com.todesktop.230313mzl4w4u92" // Cursor
        ]
        
        // When
        commonApps.forEach { manager.addExcludedApp($0) }
        
        // Then
        XCTAssertTrue(manager.isAppExcluded("com.microsoft.VSCode"))
        XCTAssertTrue(manager.isAppExcluded("com.apple.dt.Xcode"))
        XCTAssertTrue(manager.isAppExcluded("com.todesktop.230313mzl4w4u92"))
    }
}
