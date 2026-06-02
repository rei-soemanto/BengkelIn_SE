import "server-only"

import { createClient } from "@/lib/supabase/server"
import { requireAdmin } from "@/lib/auth/dal"
import type { DisputeRpcRow } from "@/types/database"
import type { Dispute } from "@/components/features/disputes/types/dispute"

export async function fetchDisputes(): Promise<Dispute[]> {
  await requireAdmin()

  const supabase = await createClient()

  const { data, error } = await supabase.rpc("admin_list_disputes")

  if (error) {
    throw error
  }

  const rows = (data ?? []) as DisputeRpcRow[]

  return rows.map((row) => ({
    id: row.id,
    status: row.status,
    reason: row.reason,
    proofUrl: row.proof_url,
    initiatorRole: row.initiator_role,
    initiatorName: row.initiator_name,
    createdAt: row.created_at,
    resolvedAt: row.resolved_at,
    serviceRequestId: row.service_request_id,
    serviceType: row.service_type,
    description: row.description,
    price: row.price,
    orderStatus: row.order_status,
    orderCreatedAt: row.order_created_at,
    customerId: row.customer_id,
    customerName: row.customer_name,
    customerEmail: row.customer_email,
    bengkelId: row.bengkel_id,
    bengkelName: row.bengkel_name,
    bengkelAddress: row.bengkel_address,
    providerUid: row.provider_uid,
    providerName: row.provider_name,
    providerEmail: row.provider_email,
  }))
}

export async function countPendingDisputes(): Promise<number> {
  await requireAdmin()

  const supabase = await createClient()

  const { count, error } = await supabase
    .from("order_disputes")
    .select("id", { count: "exact", head: true })
    .eq("status", "pending")

  if (error) {
    throw error
  }

  return count ?? 0
}
