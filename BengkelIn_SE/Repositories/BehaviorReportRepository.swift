//
//  BehaviorReportRepository.swift
//  BengkelIn
//
//  Created by Eugene on 02/06/26.
//

import Foundation
import Supabase

class BehaviorReportRepository {
    func submit(serviceRequestId: String, reporterId: String, reason: String) async throws {
        try await supabase.from("behavior_reports")
            .insert(BehaviorReportPayload(
                service_request_id: serviceRequestId,
                reporter_id: reporterId,
                reason: reason
            ))
            .execute()
    }

    func fetchReportedRequestIds(reporterId: String) async throws -> [String] {
        let rows: [ReportedRequestRow] = try await supabase.from("behavior_reports")
            .select("service_request_id")
            .eq("reporter_id", value: reporterId)
            .execute()
            .value
        return rows.map { $0.service_request_id }
    }
}
