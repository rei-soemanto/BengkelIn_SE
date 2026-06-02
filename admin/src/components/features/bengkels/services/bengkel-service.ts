import "server-only"

import { createClient } from "@/lib/supabase/server"
import { requireAdmin } from "@/lib/auth/dal"
import type {
  PendingBengkelRpcRow,
  VerifiedBengkelRpcRow,
} from "@/types/database"
import type {
  PendingBengkelDetail,
  VerifiedBengkel,
} from "@/components/features/bengkels/types/bengkel"

export async function fetchPendingBengkelDetails(): Promise<
  PendingBengkelDetail[]
> {
  await requireAdmin()

  const supabase = await createClient()

  const { data, error } = await supabase.rpc("admin_list_pending_bengkels")

  if (error) {
    throw error
  }

  const rows = (data ?? []) as PendingBengkelRpcRow[]

  return rows.map((row) => ({
    id: row.id,
    providerUid: row.provider_uid,
    name: row.name,
    address: row.address,
    latitude: row.latitude,
    longitude: row.longitude,
    status: row.status,
    createdAt: row.created_at,
    requesterName: row.requester_name,
    requesterEmail: row.requester_email,
    requesterPhone: row.requester_phone,
  }))
}

export async function fetchVerifiedBengkels(): Promise<VerifiedBengkel[]> {
  await requireAdmin()

  const supabase = await createClient()

  const { data, error } = await supabase.rpc("admin_list_verified_bengkels")

  if (error) {
    throw error
  }

  const rows = (data ?? []) as VerifiedBengkelRpcRow[]

  return rows.map((row) => ({
    id: row.id,
    providerUid: row.provider_uid,
    name: row.name,
    address: row.address,
    latitude: row.latitude,
    longitude: row.longitude,
    createdAt: row.created_at,
    averageRating: row.average_rating,
    totalReviews: row.total_reviews,
    providerName: row.provider_name,
    providerEmail: row.provider_email,
    providerPhone: row.provider_phone,
    mechanics: row.mechanics ?? [],
  }))
}

export async function countPendingBengkels(): Promise<number> {
  await requireAdmin()

  const supabase = await createClient()

  const { count, error } = await supabase
    .from("bengkels")
    .select("id", { count: "exact", head: true })
    .eq("status", "Pending")

  if (error) {
    throw error
  }

  return count ?? 0
}

export async function countVerifiedBengkels(): Promise<number> {
  await requireAdmin()

  const supabase = await createClient()

  const { count, error } = await supabase
    .from("bengkels")
    .select("id", { count: "exact", head: true })
    .eq("status", "Verified")

  if (error) {
    throw error
  }

  return count ?? 0
}
