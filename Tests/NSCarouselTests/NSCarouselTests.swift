import XCTest
@testable import NSCarousel

final class NSCarouselTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(NSCarousel().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
