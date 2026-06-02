import { fetchWithdrawals } from "@/components/features/withdrawals/services/withdrawal-service"
import { WithdrawalsTable } from "@/components/features/withdrawals/components/withdrawals-table"

export default async function PenarikanPage() {
  const withdrawals = await fetchWithdrawals()

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-col gap-1">
        <h1 className="font-heading text-xl font-medium">Permintaan Penarikan</h1>
        <p className="text-sm text-muted-foreground">
          Tinjau permintaan penarikan saldo pengguna, lalu setujui atau tolak.
        </p>
      </div>
      <WithdrawalsTable withdrawals={withdrawals} />
    </div>
  )
}
