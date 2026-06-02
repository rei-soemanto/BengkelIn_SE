import {
  Card,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import { cn } from "@/lib/utils"
import type { StatAccent } from "@/components/features/dashboard/types/dashboard"
import type { RevenueStatCardProps } from "@/components/features/revenue/types/revenue"

const accentTile: Record<StatAccent, string> = {
  amber: "bg-amber-100 text-amber-700 dark:bg-amber-500/15 dark:text-amber-400",
  emerald:
    "bg-emerald-100 text-emerald-700 dark:bg-emerald-500/15 dark:text-emerald-400",
  rose: "bg-rose-100 text-rose-700 dark:bg-rose-500/15 dark:text-rose-400",
  sky: "bg-sky-100 text-sky-700 dark:bg-sky-500/15 dark:text-sky-400",
}

export function RevenueStatCard({
  label,
  value,
  icon: Icon,
  accent,
}: RevenueStatCardProps) {
  return (
    <Card className="h-full shadow-sm">
      <CardHeader>
        <div
          className={cn(
            "flex size-10 items-center justify-center rounded-lg",
            accentTile[accent]
          )}
        >
          <Icon className="size-5" />
        </div>
        <CardTitle className="mt-3 text-2xl font-semibold tabular-nums tracking-tight">
          {value}
        </CardTitle>
        <CardDescription>{label}</CardDescription>
      </CardHeader>
    </Card>
  )
}
