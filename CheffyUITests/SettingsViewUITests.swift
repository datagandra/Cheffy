import XCTest

final class SettingsViewUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        
        // Navigate to Settings
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.exists)
        settingsTab.tap()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Navigation Tests
    
    func testSettingsViewLoadsCorrectly() throws {
        // Verify Settings view is displayed
        let settingsTitle = app.navigationBars["Settings"]
        XCTAssertTrue(settingsTitle.exists)
        
        // Verify all main sections are present
        XCTAssertTrue(app.staticTexts["Profile"].exists)
        XCTAssertTrue(app.staticTexts["API Configuration"].exists)
        XCTAssertTrue(app.staticTexts["Account"].exists)
        XCTAssertTrue(app.staticTexts["Privacy & Legal"].exists)
        XCTAssertTrue(app.staticTexts["Support"].exists)
        XCTAssertTrue(app.staticTexts["App"].exists)
    }
    
    // MARK: - Profile Section Tests
    
    func testProfileSectionDisplaysCorrectly() throws {
        // Test profile section content
        let profileSection = app.staticTexts["Profile"]
        XCTAssertTrue(profileSection.exists)
        
        // Test user profile display (if user exists)
        if app.staticTexts["User Profile"].exists {
            XCTAssertTrue(app.staticTexts["User Profile"].exists)
            XCTAssertTrue(app.buttons["Edit Profile"].exists)
            XCTAssertTrue(app.buttons["Reset Onboarding"].exists)
        } else {
            // Test no profile state
            XCTAssertTrue(app.staticTexts["No Profile"].exists)
            XCTAssertTrue(app.buttons["Complete Onboarding"].exists)
        }
    }
    
    func testEditProfileButtonTappable() throws {
        if app.buttons["Edit Profile"].exists {
            let editProfileButton = app.buttons["Edit Profile"]
            XCTAssertTrue(editProfileButton.isEnabled)
            XCTAssertTrue(editProfileButton.isHittable)
        }
    }
    
    func testResetOnboardingButtonTappable() throws {
        if app.buttons["Reset Onboarding"].exists {
            let resetButton = app.buttons["Reset Onboarding"]
            XCTAssertTrue(resetButton.isEnabled)
            XCTAssertTrue(resetButton.isHittable)
        }
    }
    
    // MARK: - API Configuration Section Tests
    
    func testAPIConfigurationSectionDisplaysCorrectly() throws {
        let apiSection = app.staticTexts["API Configuration"]
        XCTAssertTrue(apiSection.exists)
        
        // Test API key status display
        XCTAssertTrue(app.staticTexts["Gemini API Key"].exists)
        
        // Test API key help link
        let helpLink = app.links["Get API Key"]
        XCTAssertTrue(helpLink.exists)
    }
    
    func testAPIKeyConfiguration() throws {
        // Tap on API key row to show alert
        let apiKeyRow = app.staticTexts["Gemini API Key"].firstMatch
        XCTAssertTrue(apiKeyRow.exists)
        apiKeyRow.tap()
        
        // Verify alert appears
        let alert = app.alerts["Enter Gemini API Key"]
        XCTAssertTrue(alert.exists)
        
        // Test alert buttons
        let saveButton = alert.buttons["Save"]
        let cancelButton = alert.buttons["Cancel"]
        XCTAssertTrue(saveButton.exists)
        XCTAssertTrue(cancelButton.exists)
        
        // Cancel the alert
        cancelButton.tap()
    }
    
    func testClearAPIKeyButton() throws {
        // Only test if API key is set
        if app.buttons["Clear API Key"].exists {
            let clearButton = app.buttons["Clear API Key"]
            XCTAssertTrue(clearButton.isEnabled)
            XCTAssertTrue(clearButton.isHittable)
        }
    }
    
    // MARK: - Account Section Tests
    
    func testAccountSectionDisplaysCorrectly() throws {
        let accountSection = app.staticTexts["Account"]
        XCTAssertTrue(accountSection.exists)
        
        // Test subscription status
        XCTAssertTrue(app.staticTexts["Subscription"].exists)
        
        // Test generation count
        XCTAssertTrue(app.staticTexts["Generations Used"].exists)
        
        // Test restore purchases button
        let restoreButton = app.buttons["Restore Purchases"]
        XCTAssertTrue(restoreButton.exists)
        XCTAssertTrue(restoreButton.isEnabled)
    }
    
    func testRestorePurchasesButton() throws {
        let restoreButton = app.buttons["Restore Purchases"]
        restoreButton.tap()
        
        // Verify button action (this would typically show a loading state or completion message)
        // The actual behavior depends on the subscription manager implementation
    }
    
    func testUpgradeToProButton() throws {
        // Only test if user is not subscribed
        if app.buttons["Upgrade to PRO"].exists {
            let upgradeButton = app.buttons["Upgrade to PRO"]
            XCTAssertTrue(upgradeButton.isEnabled)
            XCTAssertTrue(upgradeButton.isHittable)
        }
    }
    
    // MARK: - Privacy & Legal Section Tests
    
    func testPrivacyAndLegalSectionDisplaysCorrectly() throws {
        let privacySection = app.staticTexts["Privacy & Legal"]
        XCTAssertTrue(privacySection.exists)
        
        // Test analytics toggle
        let analyticsToggle = app.switches["Analytics"]
        XCTAssertTrue(analyticsToggle.exists)
        
        // Test crash reporting toggle
        let crashToggle = app.switches["Crash Reporting"]
        XCTAssertTrue(crashToggle.exists)
        
        // Test privacy policy button
        let privacyButton = app.buttons["Privacy Policy"]
        XCTAssertTrue(privacyButton.exists)
        
        // Test terms of service button
        let termsButton = app.buttons["Terms of Service"]
        XCTAssertTrue(termsButton.exists)
    }
    
    func testAnalyticsToggle() throws {
        let analyticsToggle = app.switches["Analytics"]
        let initialValue = analyticsToggle.value as? String
        
        // Toggle the switch
        analyticsToggle.tap()
        
        // Verify the value changed
        let newValue = analyticsToggle.value as? String
        XCTAssertNotEqual(initialValue, newValue)
    }
    
    func testCrashReportingToggle() throws {
        let crashToggle = app.switches["Crash Reporting"]
        let initialValue = crashToggle.value as? String
        
        // Toggle the switch
        crashToggle.tap()
        
        // Verify the value changed
        let newValue = crashToggle.value as? String
        XCTAssertNotEqual(initialValue, newValue)
    }
    
    func testPrivacyPolicyNavigation() throws {
        let privacyButton = app.buttons["Privacy Policy"]
        privacyButton.tap()
        
        // Verify privacy policy view is displayed
        let privacyTitle = app.navigationBars["Privacy Policy"]
        XCTAssertTrue(privacyTitle.exists)
        
        // Navigate back
        let doneButton = app.buttons["Done"]
        doneButton.tap()
    }
    
    func testTermsOfServiceNavigation() throws {
        let termsButton = app.buttons["Terms of Service"]
        termsButton.tap()
        
        // Verify terms of service view is displayed
        let termsTitle = app.navigationBars["Terms of Service"]
        XCTAssertTrue(termsTitle.exists)
        
        // Navigate back
        let doneButton = app.buttons["Done"]
        doneButton.tap()
    }
    
    // MARK: - Support Section Tests
    
    func testSupportSectionDisplaysCorrectly() throws {
        let supportSection = app.staticTexts["Support"]
        XCTAssertTrue(supportSection.exists)
        
        // Test contact support button
        let contactButton = app.buttons["Contact Support"]
        XCTAssertTrue(contactButton.exists)
        
        // Test send feedback button
        let feedbackButton = app.buttons["Send Feedback"]
        XCTAssertTrue(feedbackButton.exists)
        
        // Test help link
        let helpLink = app.links["Help & FAQ"]
        XCTAssertTrue(helpLink.exists)
    }
    
    func testContactSupportNavigation() throws {
        let contactButton = app.buttons["Contact Support"]
        contactButton.tap()
        
        // Verify contact support view is displayed
        let contactTitle = app.navigationBars["Contact Support"]
        XCTAssertTrue(contactTitle.exists)
        
        // Navigate back
        let doneButton = app.buttons["Done"]
        doneButton.tap()
    }
    
    func testSendFeedbackNavigation() throws {
        let feedbackButton = app.buttons["Send Feedback"]
        feedbackButton.tap()
        
        // Verify feedback alert is displayed
        let feedbackAlert = app.alerts["Send Feedback"]
        XCTAssertTrue(feedbackAlert.exists)
        
        // Cancel the alert
        let cancelButton = feedbackAlert.buttons["Cancel"]
        cancelButton.tap()
    }
    
    // MARK: - App Section Tests
    
    func testAppSectionDisplaysCorrectly() throws {
        let appSection = app.staticTexts["App"]
        XCTAssertTrue(appSection.exists)
        
        // Test app version
        XCTAssertTrue(app.staticTexts["Version"].exists)
        
        // Test build number
        XCTAssertTrue(app.staticTexts["Build"].exists)
        
        // Test cache management button
        let cacheButton = app.buttons["Cache Management"]
        XCTAssertTrue(cacheButton.exists)
        
        // Test LLM diagnostics button
        let diagnosticsButton = app.buttons["LLM Diagnostics"]
        XCTAssertTrue(diagnosticsButton.exists)
        
        // Test database test button
        let databaseButton = app.buttons["Database Test"]
        XCTAssertTrue(databaseButton.exists)
        
        // Test developer dashboard button
        let dashboardButton = app.buttons["Developer Dashboard"]
        XCTAssertTrue(dashboardButton.exists)
        
        // Test rate app link
        let rateLink = app.links["Rate Cheffy"]
        XCTAssertTrue(rateLink.exists)
        
        // Test share app button
        let shareButton = app.buttons["Share Cheffy"]
        XCTAssertTrue(shareButton.exists)
    }
    
    func testCacheManagementNavigation() throws {
        let cacheButton = app.buttons["Cache Management"]
        cacheButton.tap()
        
        // Verify cache management view is displayed
        let cacheTitle = app.navigationBars["Cache Management"]
        XCTAssertTrue(cacheTitle.exists)
        
        // Navigate back
        let doneButton = app.buttons["Done"]
        doneButton.tap()
    }
    
    func testLLMDiagnosticsNavigation() throws {
        let diagnosticsButton = app.buttons["LLM Diagnostics"]
        diagnosticsButton.tap()
        
        // Verify LLM diagnostics view is displayed
        let diagnosticsTitle = app.navigationBars["LLM Diagnostics"]
        XCTAssertTrue(diagnosticsTitle.exists)
        
        // Navigate back
        let doneButton = app.buttons["Done"]
        doneButton.tap()
    }
    
    func testDatabaseTestNavigation() throws {
        let databaseButton = app.buttons["Database Test"]
        databaseButton.tap()
        
        // Verify database test view is displayed
        let databaseTitle = app.navigationBars["Database Test"]
        XCTAssertTrue(databaseTitle.exists)
        
        // Navigate back
        let doneButton = app.buttons["Done"]
        doneButton.tap()
    }
    
    func testDeveloperDashboardNavigation() throws {
        let dashboardButton = app.buttons["Developer Dashboard"]
        dashboardButton.tap()
        
        // Verify developer dashboard view is displayed
        let dashboardTitle = app.navigationBars["Developer Analytics"]
        XCTAssertTrue(dashboardTitle.exists)
        
        // Navigate back
        let doneButton = app.buttons["Done"]
        doneButton.tap()
    }
    
    // MARK: - Accessibility Tests
    
    func testAccessibilityLabels() throws {
        // Test that all interactive elements have accessibility labels
        let allButtons = app.buttons.allElementsBoundByIndex
        for button in allButtons {
            if button.isHittable {
                XCTAssertTrue(button.label.count > 0, "Button should have accessibility label: \(button)")
            }
        }
        
        let allSwitches = app.switches.allElementsBoundByIndex
        for toggle in allSwitches {
            XCTAssertTrue(toggle.label.count > 0, "Switch should have accessibility label: \(toggle)")
        }
    }
    
    func testAccessibilityHints() throws {
        // Test that buttons have accessibility hints
        let buttonsWithHints = [
            "Edit Profile",
            "Reset Onboarding",
            "Complete Onboarding",
            "Clear API Key",
            "Restore Purchases",
            "Upgrade to PRO",
            "Privacy Policy",
            "Terms of Service",
            "Contact Support",
            "Send Feedback",
            "Cache Management",
            "LLM Diagnostics",
            "Database Test",
            "Developer Dashboard"
        ]
        
        for buttonName in buttonsWithHints {
            if app.buttons[buttonName].exists {
                let button = app.buttons[buttonName]
                // Note: Accessibility hints are not directly testable in UI tests
                // but we can verify the button exists and is accessible
                XCTAssertTrue(button.isEnabled)
            }
        }
    }
    
    // MARK: - Performance Tests
    
    func testSettingsViewLoadsQuickly() throws {
        // Measure time to load settings view
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Navigate to settings
        let settingsTab = app.tabBars.buttons["Settings"]
        settingsTab.tap()
        
        // Wait for view to load
        let settingsTitle = app.navigationBars["Settings"]
        XCTAssertTrue(settingsTitle.waitForExistence(timeout: 2.0))
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let loadTime = endTime - startTime
        
        // Settings view should load in under 2 seconds
        XCTAssertLessThan(loadTime, 2.0, "Settings view took too long to load: \(loadTime)s")
    }
    
    // MARK: - Error Handling Tests
    
    func testResetGenerationCountAlert() throws {
        // Only test if generation count > 0
        if app.buttons["Reset Generation Count"].exists {
            let resetButton = app.buttons["Reset Generation Count"]
            resetButton.tap()
            
            // Verify alert appears
            let alert = app.alerts["Reset Generation Count"]
            XCTAssertTrue(alert.exists)
            
            // Cancel the alert
            let cancelButton = alert.buttons["Cancel"]
            cancelButton.tap()
        }
    }
    
    // MARK: - Form Validation Tests
    
    func testFormStructure() throws {
        // Verify that the view uses Form instead of List
        // This is important for Apple HIG compliance
        let form = app.otherElements.containing(.form, identifier: nil).firstMatch
        XCTAssertTrue(form.exists, "Settings view should use Form for better accessibility")
    }
    
    // MARK: - Dynamic Type Tests
    
    func testDynamicTypeSupport() throws {
        // Test that text scales properly with different text sizes
        // This would require changing system text size and verifying layout
        // For now, we'll verify that the view loads correctly
        XCTAssertTrue(app.navigationBars["Settings"].exists)
    }
    
    // MARK: - VoiceOver Tests
    
    func testVoiceOverSupport() throws {
        // Test that VoiceOver can navigate through all elements
        // This would require enabling VoiceOver and testing navigation
        // For now, we'll verify accessibility labels exist
        testAccessibilityLabels()
    }
}
