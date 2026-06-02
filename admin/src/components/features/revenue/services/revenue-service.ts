import "server-only"

import { createClient } from "@/lib/supabase/server"
import { requireAdmin } from "@/lib/auth/dal"
import type {
  RevenueSummary,
  RevenueSummaryRpc,
} from "@/components/features/revenue/types/revenue"

function toNumber(value: number | string | null): number {
  return Number(value ?? 0)
}

export async function fetchRevenueSummary(): Promise<RevenueSummary> {
  await requireAdmin()

  const supabase = await createClient()

  const { data, error } = await supabase.rpc("admin_revenue_summary")

  if (error) {
    throw error
  }

  const raw = (data ?? {}) as RevenueSummaryRpc

  return {
    totalNet: toNumber(raw.total_net),
    totalFee: toNumber(raw.total_fee),
    totalPointsRedeemed: toNumber(raw.total_points_redeemed),
    orderCount: toNumber(raw.order_count),
    series: (raw.series ?? []).map((point) => ({
      date: point.date,
      net: toNumber(point.net),
      fee: toNumber(point.fee),
    })),
  }
}
