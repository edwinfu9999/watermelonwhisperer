//
//  SweetnessLabelTests.swift
//  WatermelonWhispererTests
//

import XCTest
@testable import WatermelonWhisperer

final class SweetnessLabelTests: XCTestCase {
    func testBelowTenIsNotSweet() {
        XCTAssertEqual(SweetnessLabel(index: 0), .notSweet)
        XCTAssertEqual(SweetnessLabel(index: 9.99), .notSweet)
    }

    func testTenExactlyIsModeratelySweet() {
        XCTAssertEqual(SweetnessLabel(index: 10), .moderatelySweet)
    }

    func testElevenExactlyIsModeratelySweet() {
        XCTAssertEqual(SweetnessLabel(index: 11), .moderatelySweet)
    }

    func testBetweenTenAndElevenIsModeratelySweet() {
        XCTAssertEqual(SweetnessLabel(index: 10.5), .moderatelySweet)
    }

    func testAboveElevenIsVerySweet() {
        XCTAssertEqual(SweetnessLabel(index: 11.01), .verySweet)
        XCTAssertEqual(SweetnessLabel(index: 20), .verySweet)
    }
}
