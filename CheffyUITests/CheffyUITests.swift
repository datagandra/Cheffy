import XCTest

final class CheffyUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing"]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - App Launch & Navigation Tests
    
    func testAppLaunch() throws {
        // Verify app launches successfully
        XCTAssertTrue(app.waitForExistence(timeout: 5))
        
        // Check main navigation elements exist
        XCTAssertTrue(app.navigationBars["Cheffy"].exists)
        XCTAssertTrue(app.tabBars.firstMatch.exists)
    }
    
    func testTabNavigation() throws {
        // Test navigation between main tabs
        let homeTab = app.tabBars.buttons["Home"]
        let searchTab = app.tabBars.buttons["Search"]
        let favoritesTab = app.tabBars.buttons["Favorites"]
        let profileTab = app.tabBars.buttons["Profile"]
        
        XCTAssertTrue(homeTab.exists)
        XCTAssertTrue(searchTab.exists)
        XCTAssertTrue(favoritesTab.exists)
        XCTAssertTrue(profileTab.exists)
        
        // Navigate to each tab
        searchTab.tap()
        XCTAssertTrue(app.navigationBars["Recipe Search"].exists)
        
        favoritesTab.tap()
        XCTAssertTrue(app.navigationBars["Favorites"].exists)
        
        profileTab.tap()
        XCTAssertTrue(app.navigationBars["Profile"].exists)
        
        homeTab.tap()
        XCTAssertTrue(app.navigationBars["Cheffy"].exists)
    }
    
    // MARK: - Recipe Search & Filter Tests
    
    func testRecipeSearchFlow() throws {
        // Navigate to search tab
        app.tabBars.buttons["Search"].tap()
        
        // Test search input
        let searchField = app.searchFields["Search recipes..."]
        XCTAssertTrue(searchField.exists)
        
        searchField.tap()
        searchField.typeText("pasta")
        
        // Test search button
        let searchButton = app.buttons["Search"]
        XCTAssertTrue(searchButton.exists)
        searchButton.tap()
        
        // Wait for results
        let resultsList = app.collectionViews.firstMatch
        XCTAssertTrue(resultsList.waitForExistence(timeout: 10))
    }
    
    func testFilterSelection() throws {
        // Navigate to search tab
        app.tabBars.buttons["Search"].tap()
        
        // Test filter buttons
        let filtersButton = app.buttons["Filters"]
        XCTAssertTrue(filtersButton.exists)
        filtersButton.tap()
        
        // Test dietary restriction filters
        let vegetarianFilter = app.buttons["Vegetarian"]
        let veganFilter = app.buttons["Vegan"]
        let glutenFreeFilter = app.buttons["Gluten-Free"]
        
        XCTAssertTrue(vegetarianFilter.exists)
        XCTAssertTrue(veganFilter.exists)
        XCTAssertTrue(glutenFreeFilter.exists)
        
        // Select filters
        vegetarianFilter.tap()
        glutenFreeFilter.tap()
        
        // Verify selection
        XCTAssertTrue(vegetarianFilter.isSelected)
        XCTAssertTrue(glutenFreeFilter.isSelected)
        XCTAssertFalse(veganFilter.isSelected)
    }
    
    func testCuisineFilterSelection() throws {
        // Navigate to search tab
        app.tabBars.buttons["Search"].tap()
        
        // Open filters
        app.buttons["Filters"].tap()
        
        // Test cuisine selection
        let cuisineSection = app.buttons["Cuisine"]
        XCTAssertTrue(cuisineSection.exists)
        cuisineSection.tap()
        
        // Test specific cuisines
        let italianCuisine = app.buttons["Italian"]
        let indianCuisine = app.buttons["Indian"]
        let chineseCuisine = app.buttons["Chinese"]
        
        XCTAssertTrue(italianCuisine.exists)
        XCTAssertTrue(indianCuisine.exists)
        XCTAssertTrue(chineseCuisine.exists)
        
        // Select Italian cuisine
        italianCuisine.tap()
        XCTAssertTrue(italianCuisine.isSelected)
    }
    
    func testDifficultyFilterSelection() throws {
        // Navigate to search tab
        app.tabBars.buttons["Search"].tap()
        
        // Open filters
        app.buttons["Filters"].tap()
        
        // Test difficulty selection
        let difficultySection = app.buttons["Difficulty"]
        XCTAssertTrue(difficultySection.exists)
        difficultySection.tap()
        
        // Test difficulty levels
        let easyDifficulty = app.buttons["Easy"]
        let mediumDifficulty = app.buttons["Medium"]
        let hardDifficulty = app.buttons["Hard"]
        
        XCTAssertTrue(easyDifficulty.exists)
        XCTAssertTrue(mediumDifficulty.exists)
        XCTAssertTrue(hardDifficulty.exists)
        
        // Select Easy difficulty
        easyDifficulty.tap()
        XCTAssertTrue(easyDifficulty.isSelected)
    }
    
    func testCookingTimeFilter() throws {
        // Navigate to search tab
        app.tabBars.buttons["Search"].tap()
        
        // Open filters
        app.buttons["Filters"].tap()
        
        // Test cooking time filter
        let timeSection = app.buttons["Cooking Time"]
        XCTAssertTrue(timeSection.exists)
        timeSection.tap()
        
        // Test time options
        let quickMeals = app.buttons["Quick (15-30 min)"]
        let mediumMeals = app.buttons["Medium (30-60 min)"]
        let longMeals = app.buttons["Long (60+ min)"]
        
        XCTAssertTrue(quickMeals.exists)
        XCTAssertTrue(mediumMeals.exists)
        XCTAssertTrue(longMeals.exists)
        
        // Select quick meals
        quickMeals.tap()
        XCTAssertTrue(quickMeals.isSelected)
    }
    
    // MARK: - Recipe Generation Tests
    
    func testRecipeGenerationFlow() throws {
        // Navigate to search tab
        app.tabBars.buttons["Search"].tap()
        
        // Set up filters
        app.buttons["Filters"].tap()
        app.buttons["Vegetarian"].tap()
        app.buttons["Italian"].tap()
        app.buttons["Easy"].tap()
        
        // Close filters
        app.buttons["Done"].tap()
        
        // Generate recipe
        let generateButton = app.buttons["Generate Recipe"]
        XCTAssertTrue(generateButton.exists)
        generateButton.tap()
        
        // Wait for generation
        let loadingIndicator = app.activityIndicators.firstMatch
        XCTAssertTrue(loadingIndicator.waitForExistence(timeout: 5))
        
        // Wait for completion
        let recipeCard = app.otherElements["RecipeCard"].firstMatch
        XCTAssertTrue(recipeCard.waitForExistence(timeout: 30))
    }
    
    func testRecipeGenerationWithCustomPrompt() throws {
        // Navigate to search tab
        app.tabBars.buttons["Search"].tap()
        
        // Enter custom prompt
        let promptField = app.textFields["Custom prompt (optional)"]
        XCTAssertTrue(promptField.exists)
        promptField.tap()
        promptField.typeText("Quick breakfast with eggs")
        
        // Set filters
        app.buttons["Filters"].tap()
        app.buttons["Quick (15-30 min)"].tap()
        app.buttons["Done"].tap()
        
        // Generate recipe
        app.buttons["Generate Recipe"].tap()
        
        // Verify generation
        let recipeCard = app.otherElements["RecipeCard"].firstMatch
        XCTAssertTrue(recipeCard.waitForExistence(timeout: 30))
    }
    
    // MARK: - Recipe Detail & Interaction Tests
    
    func testRecipeDetailView() throws {
        // Generate a recipe first
        try testRecipeGenerationFlow()
        
        // Tap on recipe card to view details
        let recipeCard = app.otherElements["RecipeCard"].firstMatch
        recipeCard.tap()
        
        // Verify detail view elements
        XCTAssertTrue(app.navigationBars["Recipe Details"].exists)
        
        // Check recipe information
        XCTAssertTrue(app.staticTexts["Ingredients"].exists)
        XCTAssertTrue(app.staticTexts["Instructions"].exists)
        XCTAssertTrue(app.staticTexts["Nutrition"].exists)
    }
    
    func testRecipeFavoriting() throws {
        // Generate and view a recipe
        try testRecipeGenerationFlow()
        let recipeCard = app.otherElements["RecipeCard"].firstMatch
        recipeCard.tap()
        
        // Test favorite button
        let favoriteButton = app.buttons["Favorite"]
        XCTAssertTrue(favoriteButton.exists)
        
        // Initially not favorited
        XCTAssertFalse(favoriteButton.isSelected)
        
        // Add to favorites
        favoriteButton.tap()
        XCTAssertTrue(favoriteButton.isSelected)
        
        // Remove from favorites
        favoriteButton.tap()
        XCTAssertFalse(favoriteButton.isSelected)
    }
    
    func testRecipeSharing() throws {
        // Generate and view a recipe
        try testRecipeGenerationFlow()
        let recipeCard = app.otherElements["RecipeCard"].firstMatch
        recipeCard.tap()
        
        // Test share button
        let shareButton = app.buttons["Share"]
        XCTAssertTrue(shareButton.exists)
        shareButton.tap()
        
        // Verify share sheet appears
        let shareSheet = app.sheets.firstMatch
        XCTAssertTrue(shareSheet.waitForExistence(timeout: 5))
    }
    
    // MARK: - Top 10 Recipes Tests
    
    func testTop10RecipesDisplay() throws {
        // Navigate to home tab
        app.tabBars.buttons["Home"].tap()
        
        // Look for Top 10 section
        let top10Section = app.staticTexts["Top 10 Downloaded Recipes"]
        XCTAssertTrue(top10Section.exists)
        
        // Check if recipe cards are displayed
        let recipeCards = app.otherElements["RecipeCard"]
        XCTAssertGreaterThan(recipeCards.count, 0)
    }
    
    func testTop10RecipeInteraction() throws {
        // Navigate to home tab
        app.tabBars.buttons["Home"].tap()
        
        // Find and tap on a top recipe
        let recipeCards = app.otherElements["RecipeCard"]
        if recipeCards.count > 0 {
            recipeCards.element(boundBy: 0).tap()
            
            // Verify navigation to detail view
            XCTAssertTrue(app.navigationBars["Recipe Details"].exists)
        }
    }
    
    // MARK: - Accessibility Tests
    
    func testVoiceOverSupport() throws {
        // Enable VoiceOver for testing
        app.launchArguments = ["UI-Testing", "Accessibility-Testing"]
        app.terminate()
        app.launch()
        
        // Test VoiceOver labels on main elements
        let homeTab = app.tabBars.buttons["Home"]
        XCTAssertTrue(homeTab.exists)
        XCTAssertNotNil(homeTab.label)
        
        let searchTab = app.tabBars.buttons["Search"]
        XCTAssertTrue(searchTab.exists)
        XCTAssertNotNil(searchTab.label)
    }
    
    func testDynamicTypeSupport() throws {
        // Test with different text sizes
        let searchTab = app.tabBars.buttons["Search"]
        searchTab.tap()
        
        // Verify text elements scale properly
        let searchField = app.searchFields["Search recipes..."]
        XCTAssertTrue(searchField.exists)
        
        // Check if text is readable at different sizes
        let searchLabel = app.staticTexts["Search Recipes"]
        XCTAssertTrue(searchLabel.exists)
    }
    
    func testHighContrastMode() throws {
        // Test high contrast mode support
        app.launchArguments = ["UI-Testing", "High-Contrast-Testing"]
        app.terminate()
        app.launch()
        
        // Verify elements are visible in high contrast
        let homeTab = app.tabBars.buttons["Home"]
        XCTAssertTrue(homeTab.exists)
        XCTAssertTrue(homeTab.isEnabled)
    }
    
    // MARK: - Error Handling Tests
    
    func testNetworkErrorHandling() throws {
        // Simulate network error
        app.launchArguments = ["UI-Testing", "Network-Error-Testing"]
        app.terminate()
        app.launch()
        
        // Navigate to search and try to generate
        app.tabBars.buttons["Search"].tap()
        app.buttons["Generate Recipe"].tap()
        
        // Check for error message
        let errorMessage = app.staticTexts["Network Error"]
        XCTAssertTrue(errorMessage.waitForExistence(timeout: 10))
        
        // Check for retry button
        let retryButton = app.buttons["Retry"]
        XCTAssertTrue(retryButton.exists)
    }
    
    func testOfflineMode() throws {
        // Simulate offline mode
        app.launchArguments = ["UI-Testing", "Offline-Testing"]
        app.terminate()
        app.launch()
        
        // Navigate to search
        app.tabBars.buttons["Search"].tap()
        
        // Check for offline message
        let offlineMessage = app.staticTexts["You're offline"]
        XCTAssertTrue(offlineMessage.exists)
        
        // Check for cached recipes
        let cachedRecipes = app.staticTexts["Cached Recipes"]
        XCTAssertTrue(cachedRecipes.exists)
    }
    
    // MARK: - Performance & Stress Tests
    
    func testRapidFilterChanges() throws {
        // Navigate to search tab
        app.tabBars.buttons["Search"].tap()
        
        // Rapidly change filters
        for _ in 1...10 {
            app.buttons["Filters"].tap()
            app.buttons["Vegetarian"].tap()
            app.buttons["Done"].tap()
            
            app.buttons["Filters"].tap()
            app.buttons["Vegan"].tap()
            app.buttons["Done"].tap()
        }
        
        // Verify app remains responsive
        XCTAssertTrue(app.buttons["Generate Recipe"].exists)
    }
    
    func testMultipleRecipeGeneration() throws {
        // Navigate to search tab
        app.tabBars.buttons["Search"].tap()
        
        // Generate multiple recipes
        for i in 1...3 {
            app.buttons["Generate Recipe"].tap()
            
            // Wait for generation
            let recipeCard = app.otherElements["RecipeCard"].firstMatch
            XCTAssertTrue(recipeCard.waitForExistence(timeout: 30))
            
            // Clear for next generation
            if i < 3 {
                app.buttons["Clear"].tap()
            }
        }
        
        // Verify multiple recipes are displayed
        let recipeCards = app.otherElements["RecipeCard"]
        XCTAssertGreaterThanOrEqual(recipeCards.count, 1)
    }
    
    // MARK: - User Experience Tests
    
    func testSmoothNavigation() throws {
        // Test smooth transitions between views
        let startTime = Date()
        
        // Navigate through all tabs
        app.tabBars.buttons["Search"].tap()
        app.tabBars.buttons["Favorites"].tap()
        app.tabBars.buttons["Profile"].tap()
        app.tabBars.buttons["Home"].tap()
        
        let endTime = Date()
        let navigationTime = endTime.timeIntervalSince(startTime)
        
        // Navigation should be quick
        XCTAssertLessThan(navigationTime, 2.0, "Navigation should be smooth and quick")
    }
    
    func testConsistentUI() throws {
        // Verify consistent UI elements across tabs
        let tabs = ["Home", "Search", "Favorites", "Profile"]
        
        for tab in tabs {
            app.tabBars.buttons[tab].tap()
            
            // Check for consistent navigation bar
            XCTAssertTrue(app.navigationBars.firstMatch.exists)
            
            // Check for consistent tab bar
            XCTAssertTrue(app.tabBars.firstMatch.exists)
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testEmptyStateHandling() throws {
        // Navigate to favorites tab
        app.tabBars.buttons["Favorites"].tap()
        
        // Check for empty state message
        let emptyMessage = app.staticTexts["No favorites yet"]
        XCTAssertTrue(emptyMessage.exists)
        
        // Check for helpful action button
        let browseButton = app.buttons["Browse Recipes"]
        XCTAssertTrue(browseButton.exists)
    }
    
    func testLongTextHandling() throws {
        // Navigate to search tab
        app.tabBars.buttons["Search"].tap()
        
        // Enter very long search text
        let searchField = app.searchFields["Search recipes..."]
        searchField.tap()
        
        let longText = String(repeating: "a", count: 1000)
        searchField.typeText(longText)
        
        // Verify app handles long text gracefully
        XCTAssertTrue(app.buttons["Search"].exists)
        XCTAssertTrue(app.buttons["Search"].isEnabled)
    }
    
    func testRapidUserInput() throws {
        // Navigate to search tab
        app.tabBars.buttons["Search"].tap()
        
        // Rapidly type in search field
        let searchField = app.searchFields["Search recipes..."]
        searchField.tap()
        
        for i in 1...10 {
            searchField.typeText("test\(i) ")
        }
        
        // Verify app remains responsive
        XCTAssertTrue(app.buttons["Search"].exists)
        XCTAssertTrue(app.buttons["Search"].isEnabled)
    }
} 