import XCTest
@testable import ControllerCore

final class HIDReadingTests: XCTestCase {
    func testUnsignedAndSignedAxisRanges() {
        var axis = HIDReading(id: 1, usagePage: 1, usage: 0x30, reportID: 1, logicalMin: 0, logicalMax: 255)
        XCTAssertNil(axis.normalizedAxis)
        axis.value = 0
        XCTAssertEqual(axis.normalizedAxis, -1)
        axis.value = 255
        XCTAssertEqual(axis.normalizedAxis, 1)
        axis.value = 128
        XCTAssertEqual(axis.normalizedAxis!, 1.0 / 255, accuracy: 0.00001)
        let signed = HIDReading(id: 2, usagePage: 1, usage: 0x33, reportID: 0, logicalMin: -100, logicalMax: 100, value: 0)
        XCTAssertEqual(signed.normalizedAxis, 0)
    }

    func testInvalidRangesNullValuesAndButtonsAreNotAxes() {
        let invalid = HIDReading(id: 1, usagePage: 1, usage: 0x30, reportID: 0, logicalMin: 0, logicalMax: 0, value: 0)
        XCTAssertNil(invalid.normalizedAxis)
        let outOfRange = HIDReading(id: 2, usagePage: 1, usage: 0x30, reportID: 0, logicalMin: 0, logicalMax: 255, value: 256)
        XCTAssertNil(outOfRange.normalizedAxis)
        let hat = HIDReading(id: 3, usagePage: 1, usage: 0x39, reportID: 0, logicalMin: 0, logicalMax: 7, value: 8)
        XCTAssertNil(hat.normalizedAxis)
        let button = HIDReading(id: 4, usagePage: 9, usage: 1, reportID: 0, logicalMin: 0, logicalMax: 1, value: 1)
        XCTAssertNil(button.normalizedAxis)
        XCTAssertEqual(button.label, "Button 1")
    }
}
