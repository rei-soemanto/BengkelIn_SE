import { fetchDisputes } from "@/components/features/disputes/services/dispute-service"
import { DisputesTable } from "@/components/features/disputes/components/disputes-table"

export default async function KomplainPage() {
  const disputes = await fetchDisputes()

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-col gap-1">
        <h1 className="font-heading text-xl font-medium">Komplain Pesanan</h1>
        <p className="text-sm text-muted-foreground">
          Tinjau komplain dari pelanggan maupun bengkel, lalu putuskan apakah
          saldo dikembalikan ke pelanggan atau diteruskan ke bengkel.
        </p>
      </div>
      <DisputesTable disputes={disputes} />
    </div>
  )
}
