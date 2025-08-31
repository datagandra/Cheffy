import XCTest
@testable import Cheffy

@MainActor
final class CloudKitServiceTests: XCTestCase {
    
    var cloudKitService: CloudKitService!
    var mockNetworkClient: NetworkClient!
    var mockSecureConfigManager: SecureConfigManager!
    
    override func setUpWithError() throws {
        mockNetworkClient = NetworkClientImpl()
        mockSecureConfigManager = SecureConfigManager.shared
        cloudKitService = CloudKitService()
    }
    
    override func tearDownWithError() throws {
        cloudKitService = nil
        mockNetworkClient = nil
        mockSecureConfigManager = nil
    }
    
    // MARK: - Test Data
    
    private func createMockCrashReport() -> CrashReport {
        return CrashReport(
            appVersion: "1.0.0",
            deviceInfo: DeviceInfo(),
            errorMessage: "Test crash report",
            stackTrace: "Test stack trace",
            severity: .medium
        )
    }
    
    private func createMockUserRecipe() -> UserRecipe {
        return UserRecipe(
            title: "Test Recipe",
            ingredients: ["Ingredient 1", "Ingredient 2"],
            instructions: ["Step 1", "Step 2"],
            authorID: "test-user-id",
            cuisine: "Italian",
            difficulty: "Medium",
            prepTime: 15,
            cookTime: 30,
            servings: 4,
            dietaryNotes: ["Vegetarian"]
        )
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(cloudKitService)
        XCTAssertFalse(cloudKitService.isCloudKitAvailable)
        XCTAssertNil(cloudKitService.currentUserID)
        XCTAssertEqual(cloudKitService.syncStatus, .notAvailable)
    }
    
    // MARK: - CloudKit Status Tests
    
    func testCheckCloudKitStatus() async {
        // This test will depend on the device's actual CloudKit status
        // We'll just verify the method doesn't crash
        await cloudKitService.checkCloudKitStatus()
        
        // The status should be one of the expected values
        switch cloudKitService.syncStatus {
        case .notAvailable, .checking, .available, .syncing, .error:
            break
        }
    }
    
    // MARK: - Crash Report Tests
    
    func testUploadCrashReport() async {
        let crashReport = createMockCrashReport()
        
        // This test will fail if CloudKit is not available
        // We'll catch the error and verify it's the expected type
        do {
            try await cloudKitService.uploadCrashReport(crashReport)
            // If we get here, the upload succeeded (unlikely in test environment)
        } catch let error as CloudKitError {
            // Expected error when CloudKit is not available
            XCTAssertTrue(error == .notAvailable || error == .permissionDenied)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testFetchCrashReports() async {
        do {
            let reports = try await cloudKitService.fetchCrashReports()
            // If we get here, the fetch succeeded (unlikely in test environment)
            XCTAssertTrue(reports.isEmpty) // Should be empty in test environment
        } catch let error as CloudKitError {
            // Expected error when CloudKit is not available
            XCTAssertTrue(error == .notAvailable || error == .permissionDenied)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - User Recipe Tests
    
    func testUploadUserRecipe() async {
        let recipe = createMockUserRecipe()
        
        do {
            try await cloudKitService.uploadUserRecipe(recipe)
            // If we get here, the upload succeeded (unlikely in test environment)
        } catch let error as CloudKitError {
            // Expected error when CloudKit is not available
            XCTAssertTrue(error == .notAvailable || error == .permissionDenied)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testFetchUserRecipes() async {
        do {
            let recipes = try await cloudKitService.fetchUserRecipes()
            // If we get here, the fetch succeeded (unlikely in test environment)
            XCTAssertTrue(recipes.isEmpty) // Should be empty in test environment
        } catch let error as CloudKitError {
            // Expected error when CloudKit is not available
            XCTAssertTrue(error == .notAvailable || error == .permissionDenied)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testFetchPublicRecipes() async {
        do {
            let recipes = try await cloudKitService.fetchPublicRecipes()
            // If we get here, the fetch succeeded (unlikely in test environment)
            XCTAssertTrue(recipes.isEmpty) // Should be empty in test environment
        } catch let error as CloudKitError {
            // Expected error when CloudKit is not available
            XCTAssertTrue(error == .notAvailable || error == .permissionDenied)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testDeleteUserRecipe() async {
        let recipe = createMockUserRecipe()
        
        do {
            try await cloudKitService.deleteUserRecipe(recipe)
            // If we get here, the delete succeeded (unlikely in test environment)
        } catch let error as CloudKitError {
            // Expected error when CloudKit is not available
            XCTAssertTrue(error == .notAvailable || error == .permissionDenied)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Permission Tests
    
    func testRequestPermission() async {
        do {
            try await cloudKitService.requestPermission()
            // If we get here, the permission request succeeded (unlikely in test environment)
        } catch let error as CloudKitError {
            // Expected error when CloudKit is not available
            XCTAssertTrue(error == .notAvailable || error == .permissionDenied)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testCloudKitErrorDescriptions() {
        let errors: [CloudKitError] = [
            .notAvailable,
            .permissionDenied,
            .networkError,
            .quotaExceeded,
            .recordNotFound,
            .invalidRecord,
            .serverError("Test error"),
            .unknown(NSError(domain: "Test", code: 0))
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
}

// MARK: - Mock CloudKit Service Tests

@MainActor
final class MockCloudKitServiceTests: XCTestCase {
    
    var mockCloudKitService: MockCloudKitService!
    
    override func setUpWithError() throws {
        mockCloudKitService = MockCloudKitService()
    }
    
    override func tearDownWithError() throws {
        mockCloudKitService = nil
    }
    
    // MARK: - Mock Service Tests
    
    func testMockServiceInitialization() {
        XCTAssertTrue(mockCloudKitService.isCloudKitAvailable)
        XCTAssertEqual(mockCloudKitService.currentUserID, "mock-user-id")
        XCTAssertEqual(mockCloudKitService.syncStatus, .available)
    }
    
    func testMockCrashReportOperations() async throws {
        let crashReport = CrashReport(
            appVersion: "1.0.0",
            deviceInfo: DeviceInfo(),
            errorMessage: "Test crash",
            stackTrace: "Test stack",
            severity: .high
        )
        
        // Test upload
        try await mockCloudKitService.uploadCrashReport(crashReport)
        
        // Test fetch
        let reports = try await mockCloudKitService.fetchCrashReports()
        XCTAssertEqual(reports.count, 1)
        XCTAssertEqual(reports.first?.errorMessage, "Test crash")
    }
    
    func testMockUserRecipeOperations() async throws {
        let recipe = UserRecipe(
            title: "Test Recipe",
            ingredients: ["Ingredient 1"],
            instructions: ["Step 1"],
            authorID: "test-user"
        )
        
        // Test upload
        try await mockCloudKitService.uploadUserRecipe(recipe)
        
        // Test fetch user recipes
        let userRecipes = try await mockCloudKitService.fetchUserRecipes()
        XCTAssertEqual(userRecipes.count, 1)
        XCTAssertEqual(userRecipes.first?.title, "Test Recipe")
        
        // Test fetch public recipes
        let publicRecipes = try await mockCloudKitService.fetchPublicRecipes()
        XCTAssertEqual(publicRecipes.count, 1)
        XCTAssertEqual(publicRecipes.first?.title, "Test Recipe")
        
        // Test delete
        try await mockCloudKitService.deleteUserRecipe(recipe)
        let recipesAfterDelete = try await mockCloudKitService.fetchUserRecipes()
        XCTAssertEqual(recipesAfterDelete.count, 0)
    }
    
    func testMockServiceMethods() async {
        // These methods should not crash
        await mockCloudKitService.checkCloudKitStatus()
        
        do {
            try await mockCloudKitService.requestPermission()
        } catch {
            XCTFail("Mock service should not throw errors")
        }
    }
}
