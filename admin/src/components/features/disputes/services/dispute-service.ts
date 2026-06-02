import "server-only"

import { createClient } from "@/lib/supabase/server"
import { requireAdmin } from "@/lib/auth/dal"
import type { DisputeRpcRow } from "@/types/database"
import type {
  Dispute,
  DisputeOrder,
} from "@/components/features/disputes/types/dispute"

export async function fetchDisputeOrders(): Promise<DisputeOrder[]> {
  const disputes = await fetchDisputes()
  return groupDisputesByOrder(disputes)
}

function groupDisputesByOrder(disputes: Dispute[]): DisputeOrder[] {
  const orders = new Map<string, DisputeOrder>()

  for (const dispute of disputes) {
    const existing = orders.get(dispute.serviceRequestId)

    if (existing) {
      existing.complaints.push(dispute)
      if (dispute.status === "pending") {
        existing.pendingCount += 1
      }
      continue
    }

    orders.set(dispute.serviceRequestId, {
      serviceRequestId: dispute.serviceRequestId,
      serviceType: dispute.serviceType,
      description: dispute.description,
      price: dispute.price,
      orderStatus: dispute.orderStatus,
      orderCreatedAt: dispute.orderCreatedAt,
      customerId: dispute.customerId,
      customerName: dispute.customerName,
      customerEmail: dispute.customerEmail,
      bengkelId: dispute.bengkelId,
      bengkelName: dispute.bengkelName,
      bengkelAddress: dispute.bengkelAddress,
      providerUid: dispute.providerUid,
      providerName: dispute.providerName,
      providerEmail: dispute.providerEmail,
      complaints: [dispute],
      pendingCount: dispute.status === "pending" ? 1 : 0,
    })
  }

  return Array.from(orders.values()).sort(
    (a, b) => Number(b.pendingCount > 0) - Number(a.pendingCount > 0)
  )
}

export async function fetchDisputes(): Promise<Dispute[]> {
  await requireAdmin()

  const supabase = await createClient()

  const { data, error } = await supabase.rpc("admin_list_disputes")

  if (error) {
    throw error
  }

  const rows = (data ?? []) as DisputeRpcRow[]

  return rows.map((row) => ({
    source: row.source,
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

  const [disputes, behaviors] = await Promise.all([
    supabase
      .from("order_disputes")
      .select("id", { count: "exact", head: true })
      .eq("status", "pending"),
    supabase
      .from("behavior_reports")
      .select("id", { count: "exact", head: true })
      .eq("status", "pending"),
  ])

  if (disputes.error) {
    throw disputes.error
  }
  if (behaviors.error) {
    throw behaviors.error
  }

  return (disputes.count ?? 0) + (behaviors.count ?? 0)
}
