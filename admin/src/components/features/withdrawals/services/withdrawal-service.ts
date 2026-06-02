import "server-only"

import { createClient } from "@/lib/supabase/server"
import { requireAdmin } from "@/lib/auth/dal"
import type { WithdrawalRpcRow } from "@/types/database"
import type { Withdrawal } from "@/components/features/withdrawals/types/withdrawal"

export async function fetchWithdrawals(): Promise<Withdrawal[]> {
  await requireAdmin()

  const supabase = await createClient()

  const { data, error } = await supabase.rpc("admin_list_withdrawals")

  if (error) {
    throw error
  }

  const rows = (data ?? []) as WithdrawalRpcRow[]

  return rows.map((row) => ({
    id: row.id,
    userId: row.user_id,
    userName: row.user_name,
    userEmail: row.user_email,
    amount: row.amount,
    bankName: row.bank_name,
    bankAccountNumber: row.bank_account_number,
    bankAccountName: row.bank_account_name,
    status: row.status,
    notes: row.notes,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    userBalance: row.user_balance,
  }))
}

export async function countPendingWithdrawals(): Promise<number> {
  await requireAdmin()

  const supabase = await createClient()

  const { count, error } = await supabase
    .from("withdrawals")
    .select("id", { count: "exact", head: true })
    .eq("status", "pending")

  if (error) {
    throw error
  }

  return count ?? 0
}
