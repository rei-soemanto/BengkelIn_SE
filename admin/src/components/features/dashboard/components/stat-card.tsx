import Link from "next/link"
import { ArrowRight } from "lucide-react"
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import { cn } from "@/lib/utils"
import type { StatAccent, StatCardProps } from "@/components/features/dashboard/types/dashboard"

const accentTile: Record<StatAccent, string> = {
  amber: "bg-amber-100 text-amber-700 dark:bg-amber-500/15 dark:text-amber-400",
  emerald:
    "bg-emerald-100 text-emerald-700 dark:bg-emerald-500/15 dark:text-emerald-400",
  rose: "bg-rose-100 text-rose-700 dark:bg-rose-500/15 dark:text-rose-400",
  sky: "bg-sky-100 text-sky-700 dark:bg-sky-500/15 dark:text-sky-400",
}

const accentDot: Record<StatAccent, string> = {
  amber: "bg-amber-500",
  emerald: "bg-emerald-500",
  rose: "bg-rose-500",
  sky: "bg-sky-500",
}

export function StatCard({
  title,
  description,
  count,
  cta,
  href,
  icon: Icon,
  accent,
  attention = false,
  valueLabel,
}: StatCardProps) {
  return (
    <Link
      href={href}
      className="group block rounded-xl focus-visible:outline-none"
    >
      <Card className="h-full shadow-sm transition-all duration-200 hover:-translate-y-0.5 hover:shadow-md hover:ring-foreground/20 group-focus-visible:ring-2 group-focus-visible:ring-ring">
        <CardHeader>
          <div className="flex items-start justify-between gap-3">
            <div
              className={cn(
                "flex size-10 items-center justify-center rounded-lg",
                accentTile[accent]
              )}
            >
              <Icon className="size-5" />
            </div>
            <div className="flex items-center gap-2">
              {attention ? (
                <span
                  className={cn(
                    "size-2 animate-pulse rounded-full",
                    accentDot[accent]
                  )}
                />
              ) : null}
              <span className="text-3xl font-semibold tabular-nums tracking-tight">
                {valueLabel ?? count}
              </span>
            </div>
          </div>
          <CardTitle className="mt-3">{title}</CardTitle>
          <CardDescription>{description}</CardDescription>
        </CardHeader>
        <CardContent>
          <span className="inline-flex items-center gap-1 text-sm font-medium text-muted-foreground transition-colors group-hover:text-foreground">
            {cta}
            <ArrowRight className="size-4 transition-transform group-hover:translate-x-0.5" />
          </span>
        </CardContent>
      </Card>
    </Link>
  )
}
