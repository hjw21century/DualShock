import XCTest
@testable import ControllerCore

final class ProfileTests: XCTestCase {
    func testRadialDeadzoneAndRescaling() {
        var settings = StickSettings()
        settings.deadzone = 0.2
        XCTAssertEqual(settings.process(x: 0.1, y: 0.1).x, 0)
        XCTAssertEqual(settings.process(x: 0.6, y: 0).x, 0.5, accuracy: 0.00001)
        let diagonal = settings.process(x: 1, y: 1)
        XCTAssertEqual(hypot(diagonal.x, diagonal.y), 1, accuracy: 0.00001)
        settings.invertY = true
        XCTAssertEqual(settings.process(x: 0, y: 1).y, -1)
    }

    func testSensitivitySaturatesAndInvalidInputIsNeutral() {
        var settings = StickSettings()
        settings.sensitivity = 2
        XCTAssertEqual(settings.process(x: 1, y: 0).x, 1)
        XCTAssertEqual(settings.process(x: .nan, y: 1).y, 0)
    }

    func testMappingAndPortableRoundTrip() throws {
        var profile = ControllerProfile(name: "竞速")
        profile.mapping[PadButton.a.rawValue] = .b
        profile.leftStick.invertY = true
        let decoded = try ProfileFile.decode(ProfileFile.encode(profile))
        XCTAssertEqual(profile, decoded)
        XCTAssertEqual(decoded.mapped(.a), .b)
        XCTAssertEqual(decoded.mapped(.x), .x)
    }

    func testRejectsUnsafeImportedSettings() throws {
        var profile = ControllerProfile()
        profile.leftStick.deadzone = 1
        XCTAssertThrowsError(try ProfileFile.encode(profile))
        profile.leftStick.deadzone = 0.12
        profile.mapping["unknown"] = .a
        XCTAssertThrowsError(try ProfileFile.encode(profile))
        XCTAssertThrowsError(try ProfileFile.decode(Data("{}".utf8)))
    }
}
