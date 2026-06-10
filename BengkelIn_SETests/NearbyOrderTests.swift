//
//  NearbyOrderTests.swift
//  BengkelIn_SETests
//
//  Created by Amadeus Eugene Dirgantara on 02/06/26.
//
//  Decoding of a service_requests row into NearbyOrder (including the mechanic_id added
//  for dispatch), plus the dispatch-gate rule that decides unassigned / self / delegated.
//

import XCTest
@testable import BengkelIn_SE

final class NearbyOrderTests: XCTestCase {

    private let decoder = JSONDecoder()

    func testNearbyOrderDecodesAssignmentFields() throws {
        let json = """
        {
          "id": "order-1",
          "customer_id": "cust-1",
          "service_type": "Ban Gembos",
          "latitude": -7.28,
          "longitude": 112.79,
          "price": 50000,
          "status": "accepted",
          "bengkel_id": "bengkel-1",
          "mechanic_id": "mech-1"
        }
        """.data(using: .utf8)!

        let order = try decoder.decode(NearbyOrder.self, from: json)

        XCTAssertEqual(order.id, "order-1")
        XCTAssertEqual(order.bengkelId, "bengkel-1")
        XCTAssertEqual(order.mechanicId, "mech-1")
        XCTAssertEqual(order.price, 50000)
        XCTAssertEqual(order.status, "accepted")
    }

    func testNearbyOrderUnassignedHasNilMechanicId() throws {
        // A freshly accepted order before dispatch carries no mechanic_id.
        let json = """
        { "id": "o", "customer_id": "c", "latitude": 0, "longitude": 0, "status": "accepted",
          "bengkel_id": "b" }
        """.data(using: .utf8)!

        let order = try decoder.decode(NearbyOrder.self, from: json)
        XCTAssertNil(order.mechanicId)
    }

    // MARK: Dispatch-gate rule
    //
    // Mirrors BengkelRouteView's gate: the active-job screen is shared by provider and
    // mechanic, and the decision is purely (order.mechanicId, viewerUid).

    private func isUnassigned(_ order: NearbyOrder) -> Bool { order.mechanicId == nil }
    private func assignedToOther(_ order: NearbyOrder, viewer: String?) -> Bool {
        guard let assignee = order.mechanicId, let me = viewer else { return false }
        return assignee != me
    }

    private func makeOrder(mechanicId: String?) -> NearbyOrder {
        // Build via JSON to avoid depending on the synthesized memberwise initializer.
        let mech = mechanicId.map { "\"mechanic_id\": \"\($0)\"," } ?? ""
        let json = """
        { "id": "o", "customer_id": "c", "latitude": 0, "longitude": 0,
          "status": "accepted", "bengkel_id": "b", \(mech) "price": 1 }
        """.data(using: .utf8)!
        // swiftlint:disable:next force_try
        return try! decoder.decode(NearbyOrder.self, from: json)
    }

    func testGateUnassignedShowsAssignToProvider() {
        let order = makeOrder(mechanicId: nil)
        XCTAssertTrue(isUnassigned(order))
        XCTAssertFalse(assignedToOther(order, viewer: "provider-uid"))
    }

    func testGateSelfAssignedIsWorkUI() {
        // Provider chose "Self": mechanic_id == provider's own uid → not "other".
        let order = makeOrder(mechanicId: "provider-uid")
        XCTAssertFalse(isUnassigned(order))
        XCTAssertFalse(assignedToOther(order, viewer: "provider-uid"))
    }

    func testGateDelegatedIsMonitoringForProviderButWorkForMechanic() {
        let order = makeOrder(mechanicId: "mech-1")
        // Provider viewing a delegated job → monitoring.
        XCTAssertTrue(assignedToOther(order, viewer: "provider-uid"))
        // The assigned mechanic viewing the same job → work UI (not "other").
        XCTAssertFalse(assignedToOther(order, viewer: "mech-1"))
    }
}
