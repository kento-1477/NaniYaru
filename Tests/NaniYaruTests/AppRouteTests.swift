import XCTest
@testable import NaniYaru

final class AppRouteTests: XCTestCase {
    func testParsesDashboardURL() {
        let url = URL(string: "naniyaru://dashboard")!
        XCTAssertEqual(AppRoute.from(url: url), .dashboard)
    }

    func testParsesSectionURL() {
        let id = UUID()
        let url = URL(string: "naniyaru://section/\(id.uuidString.lowercased())")!
        XCTAssertEqual(AppRoute.from(url: url), .section(id))
    }

    func testRejectsInvalidURL() {
        let url = URL(string: "naniyaru://other")!
        XCTAssertNil(AppRoute.from(url: url))
    }

    func testBuildsDashboardURL() {
        XCTAssertEqual(AppRoute.dashboard.url.absoluteString, "naniyaru://dashboard")
    }

    func testBuildsSectionURL() {
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000123")!
        XCTAssertEqual(AppRoute.section(id).url.absoluteString, "naniyaru://section/00000000-0000-0000-0000-000000000123")
    }
}
