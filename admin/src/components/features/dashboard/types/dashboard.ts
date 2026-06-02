import type { LucideIcon } from "lucide-react"

export type StatAccent = "amber" | "emerald" | "rose" | "sky"

export interface StatCardProps {
  title: string
  description: string
  count: number
  cta: string
  href: string
  icon: LucideIcon
  accent: StatAccent
  attention?: boolean
}
