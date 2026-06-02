import { ClipboardList, Store, ShieldAlert, Banknote } from "lucide-react"
import { requireAdmin } from "@/lib/auth/dal"
import {
  countPendingBengkels,
  countVerifiedBengkels,
} from "@/components/features/bengkels/services/bengkel-service"
import { countPendingDisputes } from "@/components/features/disputes/services/dispute-service"
import { countPendingWithdrawals } from "@/components/features/withdrawals/services/withdrawal-service"
import { StatCard } from "@/components/features/dashboard/components/stat-card"

export default async function DashboardPage() {
  const admin = await requireAdmin()
  const [pendingCount, verifiedCount, disputeCount, withdrawalCount] =
    await Promise.all([
      countPendingBengkels(),
      countVerifiedBengkels(),
      countPendingDisputes(),
      countPendingWithdrawals(),
    ])

  const pendingActions = pendingCount + disputeCount + withdrawalCount

  return (
    <div className="flex flex-col gap-8">
      <div className="flex flex-col gap-1">
        <h1 className="font-heading text-2xl font-semibold tracking-tight">
          Halo, {admin.name ?? "Admin"}
        </h1>
        <p className="text-sm text-muted-foreground">
          {pendingActions > 0
            ? `Ada ${pendingActions} hal yang menunggu tindakan Anda hari ini.`
            : "Semua sudah ditangani. Tidak ada yang menunggu tindakan."}
        </p>
      </div>

      <div className="grid gap-4 sm:grid-cols-2 min-[2000px]:grid-cols-4">
        <StatCard
          title="Persetujuan Bengkel"
          description={
            pendingCount > 0
              ? `${pendingCount} pengajuan menunggu ditinjau.`
              : "Tidak ada pengajuan yang menunggu."
          }
          count={pendingCount}
          cta="Tinjau pengajuan"
          href="/bengkels"
          icon={ClipboardList}
          accent="amber"
          attention={pendingCount > 0}
        />

        <StatCard
          title="Bengkel Terverifikasi"
          description={
            verifiedCount > 0
              ? `${verifiedCount} bengkel aktif terdaftar.`
              : "Belum ada bengkel terverifikasi."
          }
          count={verifiedCount}
          cta="Lihat daftar"
          href="/bengkels/terverifikasi"
          icon={Store}
          accent="emerald"
        />

        <StatCard
          title="Komplain Pesanan"
          description={
            disputeCount > 0
              ? `${disputeCount} komplain menunggu diputuskan.`
              : "Tidak ada komplain yang menunggu."
          }
          count={disputeCount}
          cta="Tinjau komplain"
          href="/komplain"
          icon={ShieldAlert}
          accent="rose"
          attention={disputeCount > 0}
        />

        <StatCard
          title="Permintaan Penarikan"
          description={
            withdrawalCount > 0
              ? `${withdrawalCount} permintaan menunggu ditinjau.`
              : "Tidak ada permintaan penarikan."
          }
          count={withdrawalCount}
          cta="Tinjau penarikan"
          href="/penarikan"
          icon={Banknote}
          accent="sky"
          attention={withdrawalCount > 0}
        />
      </div>
    </div>
  )
}
