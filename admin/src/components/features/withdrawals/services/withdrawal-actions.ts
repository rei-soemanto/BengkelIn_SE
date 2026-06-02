"use server"

import { revalidatePath } from "next/cache"
import { createClient } from "@/lib/supabase/server"
import { requireAdmin } from "@/lib/auth/dal"
import type { WithdrawalActionResult } from "@/components/features/withdrawals/types/withdrawal"

async function reviewWithdrawal(
  rpc: "admin_approve_withdrawal" | "admin_reject_withdrawal",
  id: string
): Promise<WithdrawalActionResult> {
  await requireAdmin()

  const supabase = await createClient()

  const { error } = await supabase.rpc(rpc, { p_withdrawal_id: id })

  if (error) {
    return { ok: false, error: error.message }
  }

  revalidatePath("/penarikan")
  revalidatePath("/")

  return { ok: true }
}

export async function approveWithdrawal(
  id: string
): Promise<WithdrawalActionResult> {
  return reviewWithdrawal("admin_approve_withdrawal", id)
}

export async function rejectWithdrawal(
  id: string
): Promise<WithdrawalActionResult> {
  return reviewWithdrawal("admin_reject_withdrawal", id)
}
