import XCTest

final class SightlineUITests: XCTestCase {
    @MainActor
    func testAccessibleControlsAndRepeatedStop() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--demo"]
        app.launch()
        XCTAssertTrue(app.buttons["Start Walking Mode"].waitForExistence(timeout: 10))
        try app.performAccessibilityAudit()
        let idle = XCTAttachment(screenshot: app.screenshot())
        idle.name = "Normal text demo"
        idle.lifetime = .keepAlways
        add(idle)
        for _ in 0..<3 {
            app.buttons["Start Walking Mode"].tap()
            let stop = app.buttons["Stop"]
            if !stop.isHittable { app.swipeUp() }
            XCTAssertTrue(stop.waitForExistence(timeout: 5))
            stop.tap()
            let start = app.buttons["Start Walking Mode"]
            if !start.isHittable { app.swipeDown() }
            XCTAssertTrue(start.waitForExistence(timeout: 5))
        }
    }

    @MainActor
    func testDarkAppearanceAndActiveControls() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "--dark-demo"]
        app.launch()
        XCTAssertTrue(app.buttons["Start Walking Mode"].waitForExistence(timeout: 10))
        app.buttons["Start Walking Mode"].tap()
        app.buttons["Describe Scene"].tap()
        try app.performAccessibilityAudit()
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Dark sample session"
        shot.lifetime = .keepAlways
        add(shot)
    }

    @MainActor
    func testLargestTextAndSceneDescription() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let start = app.buttons["Start Walking Mode"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        if !start.isHittable { app.swipeUp() }
        XCTAssertGreaterThanOrEqual(start.frame.height, 44)
        start.tap()
        let describe = app.buttons["Describe Scene"]
        for _ in 0..<3 { if !describe.isHittable { app.swipeUp() } }
        XCTAssertTrue(describe.isHittable)
        describe.tap()
        for _ in 0..<10 { if !app.staticTexts["Sample description: A chair is ahead, and a bottle is to the left."].isHittable { app.swipeUp() } }
        XCTAssertTrue(app.staticTexts["Sample description: A chair is ahead, and a bottle is to the left."].isHittable)
        try app.performAccessibilityAudit()
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Largest text controls"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
