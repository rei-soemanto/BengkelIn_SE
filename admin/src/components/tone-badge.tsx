import { Badge } from "@/components/ui/badge"
import { cn } from "@/lib/utils"
import type { Tone, ToneBadgeProps } from "@/types/tone"

const toneStyles: Record<Tone, string> = {
  amber:
    "border-amber-200 bg-amber-50 text-amber-700 dark:border-amber-500/20 dark:bg-amber-500/10 dark:text-amber-400",
  emerald:
    "border-emerald-200 bg-emerald-50 text-emerald-700 dark:border-emerald-500/20 dark:bg-emerald-500/10 dark:text-emerald-400",
  rose: "border-rose-200 bg-rose-50 text-rose-700 dark:border-rose-500/20 dark:bg-rose-500/10 dark:text-rose-400",
  sky: "border-sky-200 bg-sky-50 text-sky-700 dark:border-sky-500/20 dark:bg-sky-500/10 dark:text-sky-400",
  neutral: "border-border bg-muted text-muted-foreground",
}

export function ToneBadge({ tone, children, className }: ToneBadgeProps) {
  return (
    <Badge variant="outline" className={cn(toneStyles[tone], className)}>
      {children}
    </Badge>
  )
}
