//
//  VoucherDiagnosticsView.swift
//  BengkelIn_SE
//
//  Temporary E2E test harness for the Voucher system.
//  DELETE THIS FILE after testing is complete.
//

import SwiftUI
import Supabase
import Combine

// MARK: - Lightweight diagnostic models (isolated from production)

/// Minimal Voucher decode for diagnostics — includes is_active which the prod model omits.
private struct DiagVoucher: Codable, Identifiable {
    var id: String?
    var code: String?
    var title: String?
    var discountAmount: Double?
    var validUntil: String?   // keep as String to avoid date-parse failures in diagnostics
    var isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case code
        case title
        case discountAmount = "discount_amount"
        case validUntil     = "valid_until"
        case isActive       = "is_active"
    }
}

/// Minimal UserVoucher decode with nested join for diagnostics.
private struct DiagUserVoucher: Codable, Identifiable {
    var id: String?
    var userId: String?
    var voucherId: String?
    var isUsed: Bool?
    var vouchers: DiagVoucher?   // populated by .select("*, vouchers(*)")

    enum CodingKeys: String, CodingKey {
        case id
        case userId    = "user_id"
        case voucherId = "voucher_id"
        case isUsed    = "is_used"
        case vouchers
    }
}

/// Insert DTO
private struct DiagUserVoucherInsert: Encodable {
    let userId: String
    let voucherId: String
    let isUsed: Bool

    enum CodingKeys: String, CodingKey {
        case userId    = "user_id"
        case voucherId = "voucher_id"
        case isUsed    = "is_used"
    }
}

/// Update DTO
private struct DiagUserVoucherUpdate: Encodable {
    let isUsed: Bool

    enum CodingKeys: String, CodingKey {
        case isUsed = "is_used"
    }
}

// MARK: - Step state

private enum StepStatus: Equatable {
    case idle
    case running
    case passed(String)
    case failed(String)
}

// MARK: - ViewModel

@MainActor
private class DiagnosticsVM: ObservableObject {
    @Published var steps: [StepStatus] = [.idle, .idle, .idle, .idle]
    @Published var isRunning = false

    // Artifacts carried between steps
    private var foundVoucherId: String?
    private var insertedUserVoucherId: String?
    private var currentUserId: String?

    func runAllSteps() async {
        isRunning = true
        steps = [.idle, .idle, .idle, .idle]

        // Resolve current user
        guard let session = try? await supabase.auth.session else {
            steps[0] = .failed("Not logged in. Please sign in first.")
            isRunning = false
            return
        }
        currentUserId = session.user.id.uuidString.lowercased()

        await runStep0_ReadGlobal()
        guard case .passed = steps[0] else { isRunning = false; return }

        await runStep1_Claim()
        guard case .passed = steps[1] else { isRunning = false; return }

        await runStep2_ReadWallet()
        guard case .passed = steps[2] else { isRunning = false; return }

        await runStep3_MarkUsed()

        isRunning = false
    }

    // ── Step 1: Read vouchers where is_active == true ──
    private func runStep0_ReadGlobal() async {
        steps[0] = .running
        do {
            let vouchers: [DiagVoucher] = try await supabase.from("vouchers")
                .select()
                .eq("is_active", value: true)
                .execute()
                .value

            guard let first = vouchers.first, let vId = first.id else {
                steps[0] = .failed("No active vouchers found in the table.")
                return
            }

            foundVoucherId = vId
            let summary = "Found \(vouchers.count) active voucher(s). Using: \(first.code ?? "?") (\(vId.prefix(8))…)"
            steps[0] = .passed(summary)
        } catch {
            steps[0] = .failed("DB error: \(error.localizedDescription)")
            print("[VoucherDiag] Step 0 raw error: \(error)")
        }
    }

    // ── Step 2: Insert into user_vouchers ──
    private func runStep1_Claim() async {
        steps[1] = .running
        guard let uid = currentUserId, let vid = foundVoucherId else {
            steps[1] = .failed("Missing user or voucher ID from Step 1.")
            return
        }

        // Cleanup Pre-step: Wipe the slate clean to make the test idempotent
        do {
            try await supabase.from("user_vouchers")
                .delete()
                .eq("user_id", value: uid)
                .eq("voucher_id", value: vid)
                .execute()
        } catch {
            print("[VoucherDiag] Cleanup pre-step failed (expected if no row existed): \(error)")
        }

        let payload = DiagUserVoucherInsert(userId: uid, voucherId: vid, isUsed: false)

        do {
            // Insert and return the new row so we can grab its id
            let inserted: [DiagUserVoucher] = try await supabase.from("user_vouchers")
                .insert(payload)
                .select()
                .execute()
                .value

            guard let newRow = inserted.first, let newId = newRow.id else {
                steps[1] = .failed("Insert succeeded but returned no row.")
                return
            }

            insertedUserVoucherId = newId
            steps[1] = .passed("Claimed! user_vouchers row: \(newId.prefix(8))…")
        } catch {
            steps[1] = .failed("Insert error: \(error.localizedDescription)")
            print("[VoucherDiag] Step 1 raw error: \(error)")
        }
    }

    // ── Step 3: Read wallet with FK join ──
    private func runStep2_ReadWallet() async {
        steps[2] = .running
        guard let uid = currentUserId else {
            steps[2] = .failed("Missing user ID.")
            return
        }

        do {
            let wallet: [DiagUserVoucher] = try await supabase.from("user_vouchers")
                .select("*, vouchers(*)")
                .eq("user_id", value: uid)
                .eq("is_used", value: false)
                .execute()
                .value

            guard !wallet.isEmpty else {
                steps[2] = .failed("Wallet query returned 0 rows.")
                return
            }

            // Verify that the nested join decoded correctly
            let firstItem = wallet.first!
            let nestedTitle = firstItem.vouchers?.title ?? "(nil)"
            let nestedDiscount = firstItem.vouchers?.discountAmount

            var summary = "Wallet has \(wallet.count) item(s). "
            summary += "Nested join → title: \"\(nestedTitle)\""
            if let d = nestedDiscount {
                summary += ", discount: \(d)"
            }

            if firstItem.vouchers == nil {
                steps[2] = .failed("Join returned NULL — FK relationship may be broken. Raw voucherId: \(firstItem.voucherId ?? "nil")")
            } else {
                steps[2] = .passed(summary)
            }
        } catch {
            steps[2] = .failed("Wallet read error: \(error.localizedDescription)")
            print("[VoucherDiag] Step 2 raw error: \(error)")
        }
    }

    // ── Step 4: Mark is_used = true ──
    private func runStep3_MarkUsed() async {
        steps[3] = .running
        guard let rowId = insertedUserVoucherId else {
            steps[3] = .failed("Missing user_vouchers row ID from Step 2.")
            return
        }

        let update = DiagUserVoucherUpdate(isUsed: true)

        do {
            try await supabase.from("user_vouchers")
                .update(update)
                .eq("id", value: rowId)
                .execute()

            // Verify
            let verify: [DiagUserVoucher] = try await supabase.from("user_vouchers")
                .select()
                .eq("id", value: rowId)
                .execute()
                .value

            if let row = verify.first, row.isUsed == true {
                steps[3] = .passed("is_used set to TRUE. Row \(rowId.prefix(8))… verified.")
            } else {
                steps[3] = .failed("Update ran but verification read shows is_used is still false.")
            }
        } catch {
            steps[3] = .failed("Update error: \(error.localizedDescription)")
            print("[VoucherDiag] Step 3 raw error: \(error)")
        }
    }
}

// MARK: - View

struct VoucherDiagnosticsView: View {
    @StateObject private var vm = DiagnosticsVM()

    private let stepLabels = [
        "Step 1 — Read Active Vouchers",
        "Step 2 — Claim (Insert user_vouchers)",
        "Step 3 — Read Wallet (FK Join)",
        "Step 4 — Mark Used (Update)"
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "testtube.2")
                        .font(.system(size: 48))
                        .foregroundColor(.purple)
                    Text("Voucher System Diagnostics")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("4-step E2E test against live Supabase")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.top, 16)

                // Step cards
                ForEach(0..<4, id: \.self) { i in
                    stepCard(index: i)
                }

                // Score
                let passCount = vm.steps.filter {
                    if case .passed = $0 { return true }
                    return false
                }.count

                if !vm.isRunning && passCount > 0 {
                    Text("Score: \(passCount)/4")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(passCount == 4 ? .green : .orange)
                        .padding(.top, 8)
                }

                // Run button
                Button {
                    Task { await vm.runAllSteps() }
                } label: {
                    HStack {
                        if vm.isRunning {
                            ProgressView()
                                .tint(.white)
                                .padding(.trailing, 4)
                        }
                        Image(systemName: "play.fill")
                        Text(vm.isRunning ? "Running…" : "Run Voucher Test")
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(vm.isRunning ? Color.gray : Color.purple)
                    .cornerRadius(14)
                }
                .disabled(vm.isRunning)
                .padding(.top, 8)

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Voucher Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Step Card

    @ViewBuilder
    private func stepCard(index: Int) -> some View {
        let status = vm.steps[index]
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                statusIcon(status)
                Text(stepLabels[index])
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }

            switch status {
            case .idle:
                Text("Waiting…")
                    .font(.caption)
                    .foregroundColor(.gray)
            case .running:
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Executing…")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            case .passed(let msg):
                Text(msg)
                    .font(.caption)
                    .foregroundColor(.green)
            case .failed(let msg):
                Text(msg)
                    .font(.caption)
                    .foregroundColor(.red)
                    .textSelection(.enabled)
            }
        }
        .padding()
        .background(backgroundColor(for: status))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor(for: status), lineWidth: 1.5)
        )
    }

    private func statusIcon(_ status: StepStatus) -> some View {
        Group {
            switch status {
            case .idle:
                Image(systemName: "circle")
                    .foregroundColor(.gray)
            case .running:
                Image(systemName: "arrow.trianglehead.2.counterclockwise")
                    .foregroundColor(.blue)
            case .passed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
        .font(.title3)
    }

    private func backgroundColor(for status: StepStatus) -> Color {
        switch status {
        case .idle:    return Color(.systemGray6)
        case .running: return Color.blue.opacity(0.05)
        case .passed:  return Color.green.opacity(0.05)
        case .failed:  return Color.red.opacity(0.05)
        }
    }

    private func borderColor(for status: StepStatus) -> Color {
        switch status {
        case .idle:    return Color.clear
        case .running: return Color.blue.opacity(0.3)
        case .passed:  return Color.green.opacity(0.3)
        case .failed:  return Color.red.opacity(0.3)
        }
    }
}

#Preview {
    NavigationStack {
        VoucherDiagnosticsView()
    }
}
