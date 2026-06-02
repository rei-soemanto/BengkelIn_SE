import { TrendingUp, Receipt, Star, ClipboardList, BarChart3 } from "lucide-react"
import { requireAdmin } from "@/lib/auth/dal"
import { fetchRevenueSummary } from "@/components/features/revenue/services/revenue-service"
import { RevenueStatCard } from "@/components/features/revenue/components/revenue-stat-card"
import { RevenueChart } from "@/components/features/revenue/components/revenue-chart"
import {
  Empty,
  EmptyDescription,
  EmptyHeader,
  EmptyMedia,
  EmptyTitle,
} from "@/components/ui/empty"
import { formatRupiah } from "@/lib/utils"

export default async function RevenuePage() {
  await requireAdmin()
  const summary = await fetchRevenueSummary()

  return (
    <div className="flex flex-col gap-8">
      <div className="flex flex-col gap-1">
        <h1 className="font-heading text-2xl font-semibold tracking-tight">
          Pendapatan Developer
        </h1>
        <p className="text-sm text-muted-foreground">
          Pendapatan dari biaya transaksi 10% pada setiap pesanan yang selesai.
        </p>
      </div>

      <div className="grid gap-4 sm:grid-cols-2 min-[2000px]:grid-cols-4">
        <RevenueStatCard
          label="Total Pendapatan Bersih"
          value={formatRupiah(summary.totalNet)}
          icon={TrendingUp}
          accent="emerald"
        />
        <RevenueStatCard
          label="Total Biaya Transaksi"
          value={formatRupiah(summary.totalFee)}
          icon={Receipt}
          accent="sky"
        />
        <RevenueStatCard
          label="Poin Ditukar Pelanggan"
          value={`${summary.totalPointsRedeemed} poin`}
          icon={Star}
          accent="amber"
        />
        <RevenueStatCard
          label="Pesanan Selesai"
          value={`${summary.orderCount}`}
          icon={ClipboardList}
          accent="rose"
        />
      </div>

      {summary.series.length > 0 ? (
        <RevenueChart data={summary.series} />
      ) : (
        <Empty>
          <EmptyHeader>
            <EmptyMedia variant="icon">
              <BarChart3 />
            </EmptyMedia>
            <EmptyTitle>Belum ada pendapatan</EmptyTitle>
            <EmptyDescription>
              Grafik pendapatan akan muncul setelah ada pesanan yang selesai.
            </EmptyDescription>
          </EmptyHeader>
        </Empty>
      )}
    </div>
  )
}
