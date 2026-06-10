//
//  UserAndCurrencyTests.swift
//  BengkelIn_SETests
//
//  Created by Amadeus Eugene Dirgantara on 02/06/26.
//

import XCTest
@testable import BengkelIn_SE

final class UserAndCurrencyTests: XCTestCase {

    private let decoder = JSONDecoder()

    func testUserDecodesAndComputesAvailableBalance() throws {
        let json = """
        {
          "id": "user-1",
          "name": "Andi",
          "balance": 100000,
          "held_balance": 30000,
          "role": "USER"
        }
        """.data(using: .utf8)!

        let user = try decoder.decode(User.self, from: json)

        XCTAssertEqual(user.name, "Andi")
        XCTAssertEqual(user.role, "USER")
        XCTAssertEqual(user.balance, 100000)
        XCTAssertEqual(user.heldBalance, 30000)
        XCTAssertEqual(user.availableBalance, 70000)
    }

    func testUserAvailableBalanceTreatsMissingHeldAsZero() throws {
        let json = """
        { "id": "u", "name": "B", "balance": 25000, "role": "MECHANIC" }
        """.data(using: .utf8)!

        let user = try decoder.decode(User.self, from: json)

        XCTAssertNil(user.heldBalance)
        XCTAssertEqual(user.availableBalance, 25000)
        XCTAssertEqual(user.role, "MECHANIC")
    }

    func testRupiahFormatInt() {
        let formatted = Rupiah.format(25000)
        XCTAssertTrue(formatted.contains("Rp"), "expected a Rupiah symbol in \(formatted)")
        XCTAssertTrue(formatted.contains("25.000"), "expected id_ID grouping in \(formatted)")
        XCTAssertFalse(formatted.contains(",00"), "should have no fractional digits in \(formatted)")
    }

    func testRupiahFormatDoubleRoundsToNoFraction() {
        let formatted = Rupiah.format(1500000.0)
        XCTAssertTrue(formatted.contains("Rp"))
        XCTAssertTrue(formatted.contains("1.500.000"), "expected grouped millions in \(formatted)")
    }

    func testRupiahFormatZero() {
        let formatted = Rupiah.format(0)
        XCTAssertTrue(formatted.contains("0"))
        XCTAssertTrue(formatted.contains("Rp"))
    }
}
