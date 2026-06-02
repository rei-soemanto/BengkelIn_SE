import type { ReactNode } from "react"

export type Tone = "amber" | "emerald" | "rose" | "sky" | "neutral"

export interface ToneBadgeProps {
  tone: Tone
  children: ReactNode
  className?: string
}
