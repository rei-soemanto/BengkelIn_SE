"use server"

import { revalidatePath } from "next/cache"
import { createClient } from "@/lib/supabase/server"
import { requireAdmin } from "@/lib/auth/dal"
import type { DisputeActionResult } from "@/components/features/disputes/types/dispute"

async function resolveDispute(
  id: string,
  refund: boolean
): Promise<DisputeActionResult> {
  await requireAdmin()

  const supabase = await createClient()

  const { error } = await supabase.rpc("admin_resolve_dispute", {
    p_dispute_id: id,
    p_refund: refund,
  })

  if (error) {
    return { ok: false, error: error.message }
  }

  revalidatePath("/komplain")
  revalidatePath("/")

  return { ok: true }
}

export async function refundDispute(id: string): Promise<DisputeActionResult> {
  return resolveDispute(id, true)
}

export async function payoutDispute(id: string): Promise<DisputeActionResult> {
  return resolveDispute(id, false)
}
