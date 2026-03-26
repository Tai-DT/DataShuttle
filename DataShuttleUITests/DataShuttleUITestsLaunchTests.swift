//
//  DataShuttleUITestsLaunchTests.swift
//  DataShuttleUITests
//
//  Created by tai on 26/3/26.
//

import XCTest

final class DataShuttleUITestsLaunchTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }
}
