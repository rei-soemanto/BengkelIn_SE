import type { LucideIcon } from "lucide-react"
import type { StatAccent } from "@/components/features/dashboard/types/dashboard"

export interface RevenuePoint {
  date: string
  net: number
  fee: number
}

export interface RevenueSummary {
  totalNet: number
  totalFee: number
  totalPointsRedeemed: number
  orderCount: number
  series: RevenuePoint[]
}

export interface RevenueSummaryRpc {
  total_net: number | string | null
  total_fee: number | string | null
  total_points_redeemed: number | string | null
  order_count: number | string | null
  series: Array<{
    date: string
    net: number | string | null
    fee: number | string | null
  }> | null
}

export interface RevenueChartProps {
  data: RevenuePoint[]
}

export interface RevenueStatCardProps {
  label: string
  value: string
  icon: LucideIcon
  accent: StatAccent
}
