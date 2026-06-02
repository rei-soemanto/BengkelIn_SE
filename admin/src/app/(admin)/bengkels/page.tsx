import { fetchPendingBengkelDetails } from "@/components/features/bengkels/services/bengkel-service"
import { PendingBengkelsTable } from "@/components/features/bengkels/components/pending-bengkels-table"

export default async function BengkelsPage() {
  const bengkels = await fetchPendingBengkelDetails()

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-col gap-1">
        <h1 className="font-heading text-xl font-medium">Persetujuan Bengkel</h1>
        <p className="text-sm text-muted-foreground">
          Tinjau pengajuan pendaftaran bengkel, lalu setujui atau tolak.
        </p>
      </div>
      <PendingBengkelsTable bengkels={bengkels} />
    </div>
  )
}
