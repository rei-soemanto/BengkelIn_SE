"use server"

import { revalidatePath } from "next/cache"
import { createClient } from "@/lib/supabase/server"
import { requireAdmin } from "@/lib/auth/dal"
import type { BengkelStatus } from "@/types/database"
import type { ApprovalActionResult } from "@/components/features/bengkels/types/bengkel"

async function setBengkelStatus(
  id: string,
  status: BengkelStatus
): Promise<ApprovalActionResult> {
  await requireAdmin()

  const supabase = await createClient()

  const { error } = await supabase.rpc("admin_set_bengkel_status", {
    p_bengkel_id: id,
    p_status: status,
  })

  if (error) {
    return { ok: false, error: error.message }
  }

  revalidatePath("/bengkels")
  revalidatePath("/")

  return { ok: true }
}

export async function approveBengkel(id: string): Promise<ApprovalActionResult> {
  return setBengkelStatus(id, "Verified")
}

export async function rejectBengkel(id: string): Promise<ApprovalActionResult> {
  return setBengkelStatus(id, "Rejected")
}
