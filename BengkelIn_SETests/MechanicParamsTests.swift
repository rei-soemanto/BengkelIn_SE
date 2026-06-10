//
//  MechanicParamsTests.swift
//  BengkelIn_SETests
//
//  Created by Amadeus Eugene Dirgantara on 02/06/26.
//

import XCTest
@testable import BengkelIn_SE

final class MechanicParamsTests: XCTestCase {

    private let encoder = JSONEncoder()

    private func jsonObject(_ value: Encodable) throws -> [String: Any] {
        let data = try encoder.encode(value)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testAssignParamsCarriesMechanicId() throws {
        let obj = try jsonObject(AssignMechanicParams(p_request_id: "req-1", p_mechanic_id: "mech-7"))

        XCTAssertEqual(obj["p_request_id"] as? String, "req-1")
        XCTAssertEqual(obj["p_mechanic_id"] as? String, "mech-7")
    }

    func testInviteMechanicParamsEncodesEmail() throws {
        let obj = try jsonObject(InviteMechanicParams(p_email: "budi@contoh.com"))
        XCTAssertEqual(obj["p_email"] as? String, "budi@contoh.com")
    }

    func testRespondInviteParamsEncodesAcceptFlag() throws {
        let accept = try jsonObject(RespondInviteParams(p_registration_id: "reg-1", p_accept: true))
        XCTAssertEqual(accept["p_registration_id"] as? String, "reg-1")
        XCTAssertEqual(accept["p_accept"] as? Bool, true)

        let reject = try jsonObject(RespondInviteParams(p_registration_id: "reg-1", p_accept: false))
        XCTAssertEqual(reject["p_accept"] as? Bool, false)
    }

    func testRemoveMechanicParamsEncodesRegistrationId() throws {
        let obj = try jsonObject(RemoveMechanicParams(p_registration_id: "reg-9"))
        XCTAssertEqual(obj["p_registration_id"] as? String, "reg-9")
    }
}
