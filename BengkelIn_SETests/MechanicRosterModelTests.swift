//
//  MechanicRosterModelTests.swift
//  BengkelIn_SETests
//
//  Created by Amadeus Eugene Dirgantara on 02/06/26.
//
//

import XCTest
@testable import BengkelIn_SE

final class MechanicRosterModelTests: XCTestCase {

    private let decoder = JSONDecoder()

    func testRosterMemberDecodesPendingFromSnakeCase() throws {
        let json = """
        {
          "registration_id": "reg-1",
          "mechanic_id": "mech-1",
          "mechanic_name": "Budi Santoso",
          "mechanic_email": "budi@contoh.com",
          "status": "Pending",
          "created_at": "2026-06-02T10:00:00+00:00"
        }
        """.data(using: .utf8)!

        let member = try decoder.decode(RosterMember.self, from: json)

        XCTAssertEqual(member.registrationId, "reg-1")
        XCTAssertEqual(member.mechanicId, "mech-1")
        XCTAssertEqual(member.mechanicName, "Budi Santoso")
        XCTAssertEqual(member.mechanicEmail, "budi@contoh.com")
        XCTAssertEqual(member.id, "reg-1")
        XCTAssertTrue(member.isPending)
        XCTAssertFalse(member.isAccepted)
    }

    func testRosterMemberAcceptedFlags() throws {
        let json = """
        { "registration_id": "r", "mechanic_id": "m", "mechanic_name": "A",
          "status": "Accepted" }
        """.data(using: .utf8)!

        let member = try decoder.decode(RosterMember.self, from: json)

        XCTAssertTrue(member.isAccepted)
        XCTAssertFalse(member.isPending)
        XCTAssertNil(member.mechanicEmail)
        XCTAssertNil(member.createdAt)
    }

    func testMechanicInviteDecodes() throws {
        let json = """
        {
          "registration_id": "reg-9",
          "bengkel_id": "bengkel-7",
          "bengkel_name": "Bengkel Jaya Motor",
          "status": "Pending",
          "created_at": null
        }
        """.data(using: .utf8)!

        let invite = try decoder.decode(MechanicInvite.self, from: json)

        XCTAssertEqual(invite.bengkelName, "Bengkel Jaya Motor")
        XCTAssertEqual(invite.bengkelId, "bengkel-7")
        XCTAssertEqual(invite.id, "reg-9")
        XCTAssertTrue(invite.isPending)
    }

    func testMechanicInviteRejectedIsNotPending() throws {
        let json = """
        { "registration_id": "r", "bengkel_id": "b", "bengkel_name": "X", "status": "Rejected" }
        """.data(using: .utf8)!

        let invite = try decoder.decode(MechanicInvite.self, from: json)
        XCTAssertFalse(invite.isPending)
    }

    func testAvailableMechanicDecodesAndIdentifiesByMechanicId() throws {
        let json = """
        { "mechanic_id": "mech-42", "mechanic_name": "Citra", "busy": false, "is_current": false }
        """.data(using: .utf8)!

        let mechanic = try decoder.decode(AvailableMechanic.self, from: json)

        XCTAssertEqual(mechanic.mechanicId, "mech-42")
        XCTAssertEqual(mechanic.mechanicName, "Citra")
        XCTAssertEqual(mechanic.id, "mech-42")
        XCTAssertFalse(mechanic.busy)
        XCTAssertFalse(mechanic.isCurrent)
    }

    func testAvailableMechanicArrayDecodes() throws {
        let json = """
        [ { "mechanic_id": "m1", "mechanic_name": "A", "busy": false, "is_current": false },
          { "mechanic_id": "m2", "mechanic_name": "B", "busy": true, "is_current": true } ]
        """.data(using: .utf8)!

        let list = try decoder.decode([AvailableMechanic].self, from: json)
        XCTAssertEqual(list.count, 2)
        XCTAssertEqual(list.map(\.mechanicName), ["A", "B"])
    }
}
