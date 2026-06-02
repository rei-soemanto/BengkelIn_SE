import { fetchVerifiedBengkels } from "@/components/features/bengkels/services/bengkel-service"
import { VerifiedBengkelsList } from "@/components/features/bengkels/components/verified-bengkels-list"

export default async function VerifiedBengkelsPage() {
  const bengkels = await fetchVerifiedBengkels()

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-col gap-1">
        <h1 className="font-heading text-2xl font-semibold tracking-tight">
          Bengkel Terverifikasi
        </h1>
        <p className="text-sm text-muted-foreground">
          Daftar bengkel yang telah disetujui beserta mekaniknya.
        </p>
      </div>
      <VerifiedBengkelsList bengkels={bengkels} />
    </div>
  )
}
