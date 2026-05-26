import XCTest

class CoveragePassingUITest: XCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        super.setUp()
        app.launch()
    }

    func testPass() throws {
        XCTAssertTrue(app.staticTexts["Hello World"].exists)
    }
}
