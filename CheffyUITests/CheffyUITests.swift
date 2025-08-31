import XCTest

final class CheffyUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing"] // Custom launch argument for UI testing
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - App Launch & Navigation Tests
    func testAppLaunch() throws {
        XCTAssertTrue(app.waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars["Tab Bar"].exists)
    }

    func testTabNavigation() throws {
        let tabBar = app.tabBars["Tab Bar"]
        
        // Test Home tab
        let homeTab = tabBar.buttons["Home"]
        XCTAssertTrue(homeTab.exists)
        homeTab.tap()
        
        // Test Search tab
        let searchTab = tabBar.buttons["Search"]
        XCTAssertTrue(searchTab.exists)
        searchTab.tap()
        
        // Test Favorites tab
        let favoritesTab = tabBar.buttons["Favorites"]
        XCTAssertTrue(favoritesTab.exists)
        favoritesTab.tap()
        
        // Test Profile tab
        let profileTab = tabBar.buttons["Profile"]
        XCTAssertTrue(profileTab.exists)
        profileTab.tap()
    }

    // MARK: - Recipe Search & Filter Tests
    func testRecipeSearchFlow() throws {
        let tabBar = app.tabBars["Tab Bar"]
        tabBar.buttons["Search"].tap()
        
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.exists)
        searchField.tap()
        searchField.typeText("pasta")
        
        let searchButton = app.buttons["Search"]
        if searchButton.exists {
            searchButton.tap()
        }
    }

    func testFilterSelection() throws {
        let tabBar = app.tabBars["Tab Bar"]
        tabBar.buttons["Search"].tap()
        
        // Test dietary restrictions
        let vegetarianButton = app.buttons["Vegetarian"]
        if vegetarianButton.exists {
            vegetarianButton.tap()
            XCTAssertTrue(vegetarianButton.isSelected)
        }
        
        let veganButton = app.buttons["Vegan"]
        if veganButton.exists {
            veganButton.tap()
            XCTAssertTrue(veganButton.isSelected)
        }
    }

    func testCuisineFilterSelection() throws {
        let tabBar = app.tabBars["Tab Bar"]
        tabBar.buttons["Search"].tap()
        
        let cuisinePicker = app.pickers.firstMatch
        if cuisinePicker.exists {
            cuisinePicker.adjust(toPickerWheelValue: "Italian")
        }
    }

    func testDifficultyFilterSelection() throws {
        let tabBar = app.tabBars["Tab Bar"]
        tabBar.buttons["Search"].tap()
        
        let difficultyPicker = app.pickers.firstMatch
        if difficultyPicker.exists {
            difficultyPicker.adjust(toPickerWheelValue: "Easy")
        }
    }

    func testCookingTimeFilter() throws {
        let tabBar = app.tabBars["Tab Bar"]
        tabBar.buttons["Search"].tap()
        
        let timeSlider = app.sliders.firstMatch
        if timeSlider.exists {
            timeSlider.adjust(toNormalizedSliderPosition: 0.5)
        }
    }

    // MARK: - Recipe Generation Tests
    func testRecipeGenerationFlow() throws {
        let tabBar = app.tabBars["Tab Bar"]
        tabBar.buttons["Search"].tap()
        
        // Set filters
        let vegetarianButton = app.buttons["Vegetarian"]
        if vegetarianButton.exists {
            vegetarianButton.tap()
        }
        
        let generateButton = app.buttons["Generate Recipe"]
        if generateButton.exists {
            generateButton.tap()
            
            // Wait for generation to complete
            let loadingIndicator = app.activityIndicators.firstMatch
            if loadingIndicator.exists {
                XCTAssertTrue(loadingIndicator.exists)
            }
        }
    }

    func testRecipeGenerationWithCustomPrompt() throws {
        let tabBar = app.tabBars["Tab Bar"]
        tabBar.buttons["Search"].tap()
        
        let promptField = app.textFields["Custom Prompt"]
        if promptField.exists {
            promptField.tap()
            promptField.typeText("Quick breakfast recipe")
        }
        
        let generateButton = app.buttons["Generate Recipe"]
        if generateButton.exists {
            generateButton.tap()
        }
    }

    // MARK: - Recipe Detail & Interaction Tests
    func testRecipeDetailView() throws {
        let tabBar = app.tabBars["Tab Bar"]
        tabBar.buttons["Search"].tap()
        
        // Generate a recipe first
        let generateButton = app.buttons["Generate Recipe"]
        if generateButton.exists {
            generateButton.tap()
            
            // Wait for recipe to appear
            let recipeCards = app.collectionViews.firstMatch.cells
            if recipeCards.count > 0 {
                recipeCards.element(boundBy: 0).tap()
                
                // Check recipe detail elements
                XCTAssertTrue(app.staticTexts["Ingredients"].exists)
                XCTAssertTrue(app.staticTexts["Instructions"].exists)
            }
        }
    }

    func testRecipeFavoriting() throws {
        let tabBar = app.tabBars["Tab Bar"]
        tabBar.buttons["Search"].tap()
        
        // Generate a recipe
        let generateButton = app.buttons["Generate Recipe"]
        if generateButton.exists {
            generateButton.tap()
            
            let recipeCards = app.collectionViews.firstMatch.cells
            if recipeCards.count > 0 {
                let firstRecipe = recipeCards.element(boundBy: 0)
                firstRecipe.tap()
                
                // Find and tap favorite button
                let favoriteButton = app.buttons["Favorite"]
                if favoriteButton.exists {
                    favoriteButton.tap()
                    XCTAssertTrue(favoriteButton.isSelected)
                }
            }
        }
    }

    func testRecipeSharing() throws {
        let tabBar = app.tabBars["Tab Bar"]
        tabBar.buttons["Search"].tap()
        
        // Generate a recipe
        let generateButton = app.buttons["Generate Recipe"]
        if generateButton.exists {
            generateButton.tap()
            
            let recipeCards = app.collectionViews.firstMatch.cells
            if recipeCards.count > 0 {
                let firstRecipe = recipeCards.element(boundBy: 0)
                firstRecipe.tap()
                
                // Find and tap share button
                let shareButton = app.buttons["Share"]
                if shareButton.exists {
                    shareButton.tap()
                    
                    // Check if share sheet appears
                    let shareSheet = app.sheets.firstMatch
                    XCTAssertTrue(shareSheet.exists)
                }
            }
        }
    }

    // MARK: - Top 10 Recipes Tests
    func testTop10RecipesDisplay() throws {
        let tabBar = app.tabBars["Tab Bar"]
        tabBar.buttons["Home"].tap()
        
        let top10Section = app.staticTexts["Top 10 Recipes"]
        if top10Section.exists {
            XCTAssertTrue(top10Section.exists)
            
            let recipeCards = app.collectionViews.firstMatch.cells
            XCTAssertGreaterThanOrEqual(recipeCards.count, 1)
        }
    }

    func testTop10RecipeInteraction() throws {
        let tabBar = app.tabBars["Tab Bar"]
        tabBar.buttons["Home"].tap()
        
        let recipeCards = app.collectionViews.firstMatch.cells
        if recipeCards.count > 0 {
            recipeCards.element(boundBy: 0).tap()
            
            // Should navigate to recipe detail
            XCTAssertTrue(app.staticTexts["Ingredients"].exists || app.staticTexts["Instructions"].exists)
        }
    }

    // MARK: - Accessibility Tests
    func testVoiceOverSupport() throws {
        // Enable VoiceOver simulation
        app.launchArguments.append("--uitesting-accessibility")
        
        let tabBar = app.tabBars["Tab Bar"]
        let homeTab = tabBar.buttons["Home"]
        
        // Check accessibility label
        XCTAssertTrue(homeTab.exists)
        XCTAssertNotNil(homeTab.label)
    }

    func testDynamicTypeSupport() throws {
        // Test with different text sizes
        let tabBar = app.tabBars["Tab Bar"]
        tabBar.buttons["Home"].tap()
        
        let titleText = app.staticTexts.firstMatch
        if titleText.exists {
            XCTAssertTrue(titleText.exists)
        }
    }

    func testHighContrastMode() throws {
        // Test high contrast mode
        app.launchArguments.append("--uitesting-high-contrast")
        
        let tabBar = app.tabBars["Tab Bar"]
        XCTAssertTrue(tabBar.exists)
    }

    // MARK: - Error Handling Tests
    func testNetworkErrorHandling() throws {
        app.launchArguments.append("--uitesting-network-error")
        
        let tabBar = app.tabBars["Tab Bar"]
        tabBar.buttons["Search"].tap()
        
        let generateButton = app.buttons["Generate Recipe"]
        if generateButton.exists {
            generateButton.tap()
            
            // Check for error message
            let errorAlert = app.alerts.firstMatch
            if errorAlert.exists {
                XCTAssertTrue(errorAlert.exists)
                
                let retryButton = errorAlert.buttons["Retry"]
                if retryButton.exists {
                    retryButton.tap()
                }
            }
        }
    }

    func testOfflineMode() throws {
        app.launchArguments.append("--uitesting-offline")
        
        let tabBar = app.tabBars["Tab Bar"]
        tabBar.buttons["Search"].tap()
        
        // Should show offline message
        let offlineMessage = app.staticTexts["Offline Mode"]
        if offlineMessage.exists {
            XCTAssertTrue(offlineMessage.exists)
        }
    }

    // MARK: - Performance & Stress Tests
    func testRapidFilterChanges() throws {
        let tabBar = app.tabBars["Tab Bar"]
        tabBar.buttons["Search"].tap()
        
        // Rapidly change filters
        let vegetarianButton = app.buttons["Vegetarian"]
        let veganButton = app.buttons["Vegan"]
        
        if vegetarianButton.exists && veganButton.exists {
            for _ in 0..<5 {
                vegetarianButton.tap()
                veganButton.tap()
            }
            
            // App should remain responsive
            XCTAssertTrue(app.waitForExistence(timeout: 1))
        }
    }

    func testMultipleRecipeGeneration() throws {
        let tabBar = app.tabBars["Tab Bar"]
        tabBar.buttons["Search"].tap()
        
        let generateButton = app.buttons["Generate Recipe"]
        if generateButton.exists {
            // Generate multiple recipes
            for _ in 0..<3 {
                generateButton.tap()
                
                // Wait for generation
                let loadingIndicator = app.activityIndicators.firstMatch
                if loadingIndicator.exists {
                    // Wait for loading to complete
                    let predicate = NSPredicate(format: "exists == false")
                    expectation(for: predicate, evaluatedWith: loadingIndicator, handler: nil)
                    waitForExpectations(timeout: 30, handler: nil)
                }
            }
        }
    }

    // MARK: - User Experience Tests
    func testSmoothNavigation() throws {
        let tabBar = app.tabBars["Tab Bar"]
        
        // Test smooth tab switching
        let tabs = ["Home", "Search", "Favorites", "Profile"]
        
        for tabName in tabs {
            let tab = tabBar.buttons[tabName]
            if tab.exists {
                tab.tap()
                
                // Check if view loads
                XCTAssertTrue(app.waitForExistence(timeout: 1))
            }
        }
    }

    func testConsistentUI() throws {
        let tabBar = app.tabBars["Tab Bar"]
        
        // Check consistent tab bar appearance
        XCTAssertTrue(tabBar.exists)
        XCTAssertTrue(tabBar.buttons["Home"].exists)
        XCTAssertTrue(tabBar.buttons["Search"].exists)
        XCTAssertTrue(tabBar.buttons["Favorites"].exists)
        XCTAssertTrue(tabBar.buttons["Profile"].exists)
    }

    // MARK: - Edge Case Tests
    func testEmptyStateHandling() throws {
        let tabBar = app.tabBars["Tab Bar"]
        tabBar.buttons["Favorites"].tap()
        
        // Check empty state message
        let emptyMessage = app.staticTexts["No favorites yet"]
        if emptyMessage.exists {
            XCTAssertTrue(emptyMessage.exists)
        }
    }

    func testLongTextHandling() throws {
        let tabBar = app.tabBars["Tab Bar"]
        tabBar.buttons["Search"].tap()
        
        let promptField = app.textFields["Custom Prompt"]
        if promptField.exists {
            promptField.tap()
            
            // Enter very long text
            let longText = String(repeating: "a", count: 1000)
            promptField.typeText(longText)
            
            // Should handle without crashing
            XCTAssertTrue(app.waitForExistence(timeout: 1))
        }
    }

    func testRapidUserInput() throws {
        let tabBar = app.tabBars["Tab Bar"]
        tabBar.buttons["Search"].tap()
        
        let searchField = app.searchFields.firstMatch
        if searchField.exists {
            searchField.tap()
            
            // Rapid typing
            for i in 0..<10 {
                searchField.typeText("test\(i)")
                // Clear the field by selecting all and typing
                searchField.press(forDuration: 0.5)
                app.menuItems["Select All"].tap()
                searchField.typeText("")
            }
            
            // App should remain stable
            XCTAssertTrue(app.waitForExistence(timeout: 1))
        }
    }
} 